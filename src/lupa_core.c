#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifndef _WIN32
#include <unistd.h>
#endif

#include <uv.h>
#include <lua.h>
#include <lauxlib.h>
#include <uv-private/ngx-queue.h>

#define LUP_TASK_TNAME  "lupa.Task"
#define LUP_SCHED_TNAME "lupa.Scheduler"
#define LUP_FILE_TNAME  "lupa.File"

#define LUP_TASK_INIT  0
#define LUP_TASK_ALIVE 1
#define LUP_TASK_READY 2
#define LUP_TASK_DEAD  4

#define LUP_BUF_SIZE 4096

struct lup_Sched;

typedef struct lup_Task {
  int              ref;
  int              coref;
  unsigned int     flags;
  void             *data;
  lua_State        *state;
  struct lup_Task  *next;
  struct lup_Sched *sched;
} lup_Task;

typedef struct lup_Sched {
  lup_Task *head; 
  lup_Task *tail; 
  lup_Task *idle;
  lup_Task *curr;
} lup_Sched;

typedef struct lup_File {
  uv_file          fh;
  void             *buf;
  struct lup_Sched *sched;
} lup_File;

static int lup_Task_new(lua_State *L) {
  lua_State *state;
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);

  lup_Task *task = NULL;
  int ref, coref, nargs, type;

  nargs = lua_gettop(L) - 1;
  type  = lua_type(L, 2);

  switch (type) {
    case LUA_TTHREAD:
      state = lua_tothread(L, 2);
      break;
    case LUA_TFUNCTION:
      state = lua_newthread(L);
      if (!state) return 0;
      break;
    default:
      luaL_error(L, "argument #2 needs to be a function");
  }

  /* sched, func, ..., thread */

  lua_checkstack(state, nargs);
  lua_insert(L, 2);                       /* sched, thread, func, ... */
  lua_xmove(L, state, nargs);             /* sched, thread */

  /* stash the state in the registry */
  coref = luaL_ref(L, LUA_REGISTRYINDEX); /* sched */

  task = lua_newuserdata(L, sizeof(lup_Task));
  if (!task) return 0;                    /* sched, task */

  luaL_getmetatable(L, LUP_TASK_TNAME);   /* sched, task, meta */
  lua_setmetatable(L, -2);                /* sched, task */

  /* stash the task in the registry */
  lua_pushvalue(L, -1);                   /* sched, task, task */
  ref = luaL_ref(L, LUA_REGISTRYINDEX);   /* sched, task */

  task->sched  = sched;
  task->state  = state;
  task->ref    = ref;
  task->coref  = coref;
  task->next   = NULL;
  task->flags  = LUP_TASK_INIT;
  task->data   = NULL;

  return 1;
}

static int lup_Sched_new(lua_State *L) {
  lup_Sched *sched = lua_newuserdata(L, sizeof(lup_Sched));
  luaL_getmetatable(L, LUP_SCHED_TNAME);
  lua_setmetatable(L, -2);

  sched->head = NULL;
  sched->tail = NULL;
  sched->idle = NULL;
  sched->curr = NULL;

  return 1;
}

#define lup_sched_enqueue(S, T) \
  do { \
    if (!(S)->head) (S)->head = (T); \
    if ((S)->tail) (S)->tail->next = (T); \
    (S)->tail = (T); \
    (T)->flags |= LUP_TASK_READY; \
    (T)->sched = (S); \
  } while (0);

#define lup_service_events(S, E) \
  do { \
    while (!(S)->head && !ngx_queue_empty(&(E)->active_reqs)) { \
      uv_run_once(E); \
    } \
  } while (0);

static int lup_sched_run(lua_State *L) {
  int stat, narg;
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  lup_Task  *task  = sched->head;
  uv_loop_t *loop  = uv_default_loop();

  while (task) {
    sched->head = task->next;
    task->next = NULL;

    if (!(task->flags & LUP_TASK_READY)) {
      task = sched->head;
      goto loop;
    }

    if (task->flags & LUP_TASK_DEAD) {
      task = sched->head;
      if (task->ref) {
        luaL_unref(L, LUA_REGISTRYINDEX, task->ref);
        luaL_unref(L, LUA_REGISTRYINDEX, task->coref);
        task->ref = 0;
        task->coref = 0;
      }
      goto loop;
    }

    narg = lua_gettop(task->state);
    if (!(task->flags & LUP_TASK_ALIVE)) {
      task->flags |= LUP_TASK_ALIVE;
      --narg; /* first entry, ignore function */
    }

    sched->curr = task;
    stat = lua_resume(task->state, narg);
    sched->curr = NULL;

    if (sched->idle && !sched->head) {
      printf("enqueue idle");
      lup_sched_enqueue(sched, sched->idle);
    }

    switch (stat) {
    case LUA_YIELD:
      /* int nret = lua_gettop(task->state); */
      if (task->flags & LUP_TASK_READY) {
        lup_sched_enqueue(sched, task);
      }
      break;
    case 0: /* normal exit, dequeue */
      task->flags = LUP_TASK_DEAD;
      if (task == sched->idle) {
        sched->idle = NULL;
        if (sched->head == task) {
          sched->head = NULL;
        }
      }
      if (task->ref) {
        luaL_unref(L, LUA_REGISTRYINDEX, task->ref);
        luaL_unref(L, LUA_REGISTRYINDEX, task->coref);
        task->ref = 0;
      }
      break;
    default:
      lua_pushvalue(task->state, -1);  /* error_message */
      lua_xmove(task->state, L, 1);
      lua_error(L);
    }

    loop:
    lup_service_events(sched, loop);

    task = sched->head;
  }

  return 0;
}

static int lup_sched_put(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  if (lup_Task_new(L)) {
    lup_Task *task = luaL_checkudata(L, -1, LUP_TASK_TNAME);
    lup_sched_enqueue(sched, task);
    return 1;
  }
  return 0;
}

static int lup_sched_stop(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  (void)sched;
  return 0;
}

static int lup_task_cancel(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  task->flags |= LUP_TASK_DEAD;
  lup_sched_enqueue(task->sched, task);
  return 1;
}
static int lup_task_suspend(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  if (!(task->flags & LUP_TASK_ALIVE)) {
    luaL_error(L, "cannot suspend a dead task");
  }
  task->flags &= ~LUP_TASK_READY;
  return 1;
}
static int lup_task_resume(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  if (!(task->flags & LUP_TASK_ALIVE)) {
    luaL_error(L, "cannot resume a dead task");
  }
  task->flags |= LUP_TASK_READY;
  return 1;
}

static int lup_task_join(lua_State *L) {
  int nret = 0;
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  while (task->flags & LUP_TASK_READY) {
    lua_pushlightuserdata(L, task->sched);
    lua_replace(L, 1);
    lua_settop(L, 1);
    lua_yield(L, 0);
  }
  nret = lua_gettop(task->state);
  return nret;
}

static int lup_task_free(lua_State *L) {
  puts(__func__);
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  if (task->data) free(task->data);
  return 1;
}

static int lup_sched_set_idle(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  if (lua_isnil(L, 2)) {
    sched->idle = NULL;
    return 0;
  }
  else {
    if (lup_Task_new(L)) {
      sched->idle = luaL_checkudata(L, -1, LUP_TASK_TNAME);
    }
    else {
      luaL_error(L, "failed to create task");
    }
  }

  return 0;
}

static int lup_sched_get_idle(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  if (sched->idle) {
    lua_pushthread(sched->idle->state);
  }
  else {
    lua_pushnil(L);
  }
  return 1;
}

static int string_to_flags(lua_State* L, const char* str) {
  if (strcmp(str, "r") == 0)
    return O_RDONLY;
  if (strcmp(str, "r+") == 0)
    return O_RDWR;
  if (strcmp(str, "w") == 0)
    return O_CREAT | O_TRUNC | O_WRONLY;
  if (strcmp(str, "w+") == 0)
    return O_CREAT | O_TRUNC | O_RDWR;
  if (strcmp(str, "a") == 0)
    return O_APPEND | O_CREAT | O_WRONLY;
  if (strcmp(str, "a+") == 0)
    return O_APPEND | O_CREAT | O_RDWR;
  return luaL_error(L, "Unknown file open flag: '%s'", str);
}

static void fs_cb(uv_fs_t *req) {
  lup_Task *task = req->data;
  if (task) {
    lua_State *state = task->state;
    lup_sched_enqueue(task->sched, task);
    lup_File *file = luaL_checkudata(state, 1, LUP_FILE_TNAME);

    if (req->result == -1) {
      lua_pop(state, 1); /* file object */
      lua_pushnil(state);
      lua_pushinteger(state, (uv_err_code)req->errorno);
    }
    else {
      switch (req->fs_type) {
      case UV_FS_CLOSE:
        lua_pop(state, 1); /* file object */
        lua_pushinteger(state, req->result);
        break;
      case UV_FS_OPEN:
        file->fh = req->result;
        break;
      case UV_FS_READ:
        lua_pop(state, 1); /* file object */
        lua_pushinteger(state, req->result);
        lua_pushlstring(state, file->buf, req->result);
        free(file->buf);
        break;
      case UV_FS_WRITE:
        lua_pop(state, 1); /* file object */
        lua_pushinteger(state, req->result);
        break;
      default:
        luaL_error(state, "Unhandled fs_type");
      }
    }
    uv_fs_req_cleanup(req);
    free(req);
  }
}

/* file:read(len, ofs) */
static int lup_file_read(lua_State *L) {
  lup_File *file = luaL_checkudata(L, 1, LUP_FILE_TNAME);

  lua_State *state;
  uv_loop_t *loop  = uv_default_loop();
  lup_Sched *sched = file->sched;
  lup_Task  *task  = sched->curr;

  int rv;

  size_t len  = luaL_optint(L, 2, LUP_BUF_SIZE);
  int64_t ofs = luaL_optint(L, 3, -1);

  file->buf = malloc(len);

  uv_fs_t* req = malloc(sizeof(uv_fs_t));

  state = task ? task->state : L;
  req->data = task; /* NULL if main */

  rv = uv_fs_read(loop, req, file->fh, file->buf, len, ofs, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task) {
    task->flags &= ~LUP_TASK_READY;
    return lua_yield(state, 2);
  }
  else {
    /* main */
    lup_service_events(sched, loop);
    return 2;
  }
}

static int lup_file_write(lua_State *L) {
  lup_File*  file  = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lup_Sched* sched = file->sched;
  lup_Task*  task  = sched->curr;
  lua_State* state;

  uv_loop_t* loop  = uv_default_loop();

  int      rv;
  size_t   len;
  void*    buf = (void*)luaL_checklstring(L, 2, &len);
  uint64_t ofs = luaL_optint(L, 3, 0);
  uv_fs_t* req = malloc(sizeof(uv_fs_t));

  state = task ? task->state : L;
  req->data = task; /* NULL if main */

  rv = uv_fs_write(loop, req, file->fh, buf, len, ofs, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task) {
    task->flags &= ~LUP_TASK_READY;
    return lua_yield(state, 1);
  }
  else {
    /* main */
    lup_service_events(sched, loop);
    return 1;
  }
}

static int lup_file_close(lua_State *L) {
  lup_File*  file  = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lup_Sched* sched = file->sched;
  lup_Task*  task  = sched->curr;
  lua_State* state;
  int rv;

  uv_loop_t* loop = uv_default_loop();
  uv_fs_t*   req  = malloc(sizeof(uv_fs_t));

  state = task ? task->state : L;
  req->data = task;

  rv = uv_fs_close(loop, req, file->fh, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task) {
    task->flags &= ~LUP_TASK_READY;
    return lua_yield(state, 1);
  }
  else {
    /* main */
    lup_service_events(sched, loop);
    return 1;
  }
}

static int lup_sched_open(lua_State* L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  const char* path = luaL_checkstring(L, 2);
  int flags  = string_to_flags(L, luaL_checkstring(L, 3));
  int mode   = strtoul(luaL_checkstring(L, 4), NULL, 8);
  lup_File *file = NULL;
  int rv     = 0;

  lua_State *state = NULL;
  uv_fs_t* req     = malloc(sizeof(uv_fs_t));
  uv_loop_t *loop  = uv_default_loop();

  lup_Task *task = sched->curr;
  req->data = task; /* NULL if in main thread */

  lua_settop(L, 1);

  rv = uv_fs_open(uv_default_loop(), req, path, flags, mode, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  state = task ? task->state : L;

  file = lua_newuserdata(state, sizeof(lup_File));
  luaL_getmetatable(state, LUP_FILE_TNAME);
  lua_setmetatable(state, -2);

  file->sched = sched;
  file->fh    = 0;
  file->buf   = NULL;

  if (task) {
    task->flags &= ~LUP_TASK_READY;
    return lua_yield(state, 1);
  }
  else {
    /* main */
    lup_service_events(sched, loop);
    return 1;
  }
}

int lup_sched_tostring(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_SCHED_TNAME, sched);
  return 1;
}
int lup_task_tostring(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_TASK_TNAME, task);
  return 1;
}
int lup_file_tostring(lua_State *L) {
  lup_File *file = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_FILE_TNAME, file);
  return 1;
}

static luaL_Reg lup_Task_meths[] = {
  {"join",      lup_task_join},
  {"cancel",    lup_task_cancel},
  {"suspend",   lup_task_suspend},
  {"resume",    lup_task_resume},
  {"__gc",      lup_task_free},
  {"__tostring",lup_task_tostring},
  {NULL,        NULL}
};

static luaL_Reg lup_Sched_meths[] = {
  {"put",       lup_sched_put},
  {"run",       lup_sched_run},
  {"stop",      lup_sched_stop},
  {"open",      lup_sched_open},
  {"set_idle",  lup_sched_set_idle},
  {"get_idle",  lup_sched_get_idle},
  {"__tostring",lup_sched_tostring},
  {NULL,        NULL}
};

static luaL_Reg lup_lib_funcs[] = {
  {"new",       lup_Sched_new},
  {NULL,        NULL}
};

static luaL_Reg lup_File_meths[] = {
  {"read",      lup_file_read},
  {"write",     lup_file_write},
  {"close",     lup_file_close},
  {"__tostring",lup_file_tostring},
  {NULL,        NULL}
};

int luaopen_kernel(lua_State *L) {
  /* create task metatable */
  luaL_newmetatable(L, LUP_TASK_TNAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, lup_Task_meths);

  /* create sched metatable */
  luaL_newmetatable(L, LUP_SCHED_TNAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, lup_Sched_meths);

  /* create file metatable */
  luaL_newmetatable(L, LUP_FILE_TNAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, lup_File_meths);

  /* lib table */
  lua_newtable(L);
  luaL_register(L, NULL, lup_lib_funcs);

  return 1;
}

