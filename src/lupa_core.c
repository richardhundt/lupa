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

#define LUP_BUF_SIZE 4096

typedef struct lup_Task_s lup_Task;

typedef struct lup_Sched {
  ngx_queue_t ready;
  ngx_queue_t clean;
  int         nwait;
  uv_loop_t   *loop;
  lup_Task    *main;
  lup_Task    *curr;
} lup_Sched;

static lup_Sched* __lup_default_sched;

struct lup_Task_s {
  ngx_queue_t queue;
  int         ref;
  int         coref;
  int         ready;
  void        *data;
  lua_State   *state;
  lup_Sched   *sched;
};

typedef struct lup_File {
  uv_file     fh;
  void        *buf;
  lup_Sched   *sched;
} lup_File;

static int lup_Task_new(lua_State *L) {
  lua_State *state;
  /*
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  */

  lup_Task *task = NULL;
  int ref, coref, narg, type;

  narg = lua_gettop(L) - 1;
  type = lua_type(L, 2);

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

  lua_checkstack(state, narg);
  lua_insert(L, 2);                       /* sched, thread, func, ... */
  lua_xmove(L, state, narg);              /* sched, thread */

  /* stash the state in the registry */
  coref = luaL_ref(L, LUA_REGISTRYINDEX); /* sched */

  task = lua_newuserdata(L, sizeof(lup_Task));
  if (!task) return 0;                    /* sched, task */

  luaL_getmetatable(L, LUP_TASK_TNAME);   /* sched, task, meta */
  lua_setmetatable(L, -2);                /* sched, task */

  /* stash the task in the registry */
  lua_pushvalue(L, -1);                   /* sched, task, task */
  ref = luaL_ref(L, LUA_REGISTRYINDEX);   /* sched, task */

  task->state  = state;
  task->ref    = ref;
  task->coref  = coref;
  task->ready  = 0;
  task->data   = NULL;
  task->sched  = NULL;

  return 1;
}

static int lup_Sched_new(lua_State *L) {
  lup_Sched *sched = lua_newuserdata(L, sizeof(lup_Sched));
  luaL_getmetatable(L, LUP_SCHED_TNAME);
  lua_setmetatable(L, -2);
  ngx_queue_init(&sched->ready);

  /* init main task */
  lua_pushthread(L);
  lup_Task_new(L);

  sched->main = lua_touserdata(L, -1);
  sched->curr = sched->main;
  sched->main->sched = sched;
  sched->nwait = 0;

  lua_pop(L, 1);
  return 1;
}

#define lup_sched_events(S, E) \
  while (ngx_queue_empty(&(S)->ready) && (S)->nwait > 0) \
    uv_run_once(E)

#define lup_task_unref(T) \
  luaL_unref(task->state, LUA_REGISTRYINDEX, task->ref); \
  luaL_unref(task->state, LUA_REGISTRYINDEX, task->coref); \
  task->ref = 0

#define lup_sched_enqueue(S, T) \
  ngx_queue_insert_tail(&(S)->ready, &(T)->queue)

static int lup__sched_loop(lua_State* L, lup_Sched *sched);

static int lup_sched_run(lua_State* L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  return lup__sched_loop(L, sched);
}

static int lup__sched_loop(lua_State* L, lup_Sched *sched) {
  int stat, narg;
  lup_Task  *task;
  uv_loop_t *loop = uv_default_loop();

  ngx_queue_t *ready = &sched->ready;
  ngx_queue_t *q;

  while (!ngx_queue_empty(ready)) {
    q = ngx_queue_head(ready);
    ngx_queue_remove(q);
    task = ngx_queue_data(q, lup_Task, queue);

    narg = lua_gettop(task->state);
    if (!task->sched) {
      task->sched = sched;
      narg--; /* first time seen, ignore function argument */
    }

    sched->curr = task;
    stat = lua_resume(task->state, narg);
    sched->curr = sched->main;

    switch (stat) {
      case LUA_YIELD:
        if (task->ready) {
          /* via coroutine.yield() probably */
          ngx_queue_insert_tail(ready, &task->queue);
        }
        break;
      case 0: /* normal exit, drop references */
        if (task->ref) lup_task_unref(task);
        break;
      default:
        lua_pushvalue(task->state, -1);  /* error message */
        lua_xmove(task->state, L, 1);
        lua_error(L);
    }

    lup_sched_events(sched, loop);
  }

  return 0;
}

#define lup__task_resume(S, T) \
  do { \
    if (!(T)->ready) { \
      (T)->ready = 1; --(S)->nwait; \
      lup_sched_enqueue((S), (T)); \
    } \
  } while (0)

#define lup__task_suspend(S, T) \
  do { \
    if ((T)->ready) { \
      (T)->ready = 0; ++(S)->nwait; \
      ngx_queue_remove(&(T)->queue); \
    } \
  } while (0)

static int lup_sched_put(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  if (lup_Task_new(L)) {
    lup_Task *task = luaL_checkudata(L, -1, LUP_TASK_TNAME);
    ++sched->nwait;
    lup__task_resume(sched, task);
    return 1;
  }
  return 0;
}

static int lup_sched_stop(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  (void)sched;
  return 0;
}

static int lup_task_suspend(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  lup__task_suspend(task->sched, task);
  return 1;
}
static int lup_task_resume(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  lup__task_resume(task->sched, task);
  return 1;
}

static int lup_task_join(lua_State *L) {
  int nret = 0;
  lup_Task  *task  = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  lup_Sched *sched = task->sched;
  lup_Task  *curr  = sched->curr;

  lup__task_suspend(sched, curr);

  int stat = lua_status(task->state);
  while (stat != 0 || stat == LUA_YIELD) {
    lup__sched_loop(L, sched);
    stat = lua_status(task->state);
  }

  lup__task_resume(sched, curr);

  nret = lua_gettop(task->state);
  lua_xmove(task->state, L, nret);
  return nret;
}

static int lup_task_free(lua_State *L) {
  puts(__func__);
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  if (task->data) free(task->data);
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
    lup__task_resume(task->sched, task);
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
        file->buf = NULL;
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

  uv_loop_t *loop  = uv_default_loop();
  lup_Sched *sched = file->sched;
  lup_Task  *task  = sched->curr;

  int rv;
  size_t len  = luaL_optint(L, 2, LUP_BUF_SIZE);
  int64_t ofs = luaL_optint(L, 3, -1);

  file->buf = malloc(len);
  uv_fs_t* req = malloc(sizeof(uv_fs_t));
  req->data = task;

  rv = uv_fs_read(loop, req, file->fh, file->buf, len, ofs, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task == sched->main) {
    lup_sched_events(sched, loop);
    return 2;
  }
  else {
    lup__task_suspend(sched, task);
    return lua_yield(task->state, 2);
  }
}

static int lup_file_write(lua_State *L) {
  lup_File*  file  = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lup_Sched* sched = file->sched;
  lup_Task*  task  = sched->curr;

  uv_loop_t* loop  = uv_default_loop();

  int      rv;
  size_t   len;
  void*    buf = (void*)luaL_checklstring(L, 2, &len);
  uint64_t ofs = luaL_optint(L, 3, 0);
  uv_fs_t* req = malloc(sizeof(uv_fs_t));

  req->data = task;

  rv = uv_fs_write(loop, req, file->fh, buf, len, ofs, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task == sched->main) {
    lup_sched_events(sched, loop);
    return 1;
  }
  else {
    lup__task_suspend(sched, task);
    return lua_yield(task->state, 1);
  }
}

static int lup_file_close(lua_State *L) {
  lup_File*  file  = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lup_Sched* sched = file->sched;
  lup_Task*  task  = sched->curr;
  int rv;

  uv_loop_t* loop = uv_default_loop();
  uv_fs_t*   req  = malloc(sizeof(uv_fs_t));

  req->data = task;

  rv = uv_fs_close(loop, req, file->fh, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  lua_settop(L, 1);
  if (task == sched->main) {
    lup_sched_events(sched, loop);
    return 1;
  }
  else {
    lup__task_suspend(sched, task);
    return lua_yield(task->state, 1);
  }
}

static int lup_sched_open(lua_State* L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  const char* path = luaL_checkstring(L, 2);
  int flags  = string_to_flags(L, luaL_checkstring(L, 3));
  int mode   = strtoul(luaL_checkstring(L, 4), NULL, 8);
  lup_File *file = NULL;
  int rv = 0;

  uv_loop_t *loop = uv_default_loop();
  uv_fs_t   *req  = malloc(sizeof(uv_fs_t));
  lup_Task  *task = sched->curr;
  req->data = task;

  lua_settop(L, 1);

  rv = uv_fs_open(uv_default_loop(), req, path, flags, mode, fs_cb);
  if (rv) {
    uv_err_t err = uv_last_error(loop);
    lua_pushstring(L, uv_strerror(err));
    return lua_error(L);
  }

  file = lua_newuserdata(task->state, sizeof(lup_File));
  luaL_getmetatable(task->state, LUP_FILE_TNAME);
  lua_setmetatable(task->state, -2);

  file->sched = sched;
  file->fh    = 0;
  file->buf   = NULL;

  if (task == sched->main) {
    lup_sched_events(sched, loop);
    return 1;
  }
  else {
    lup__task_suspend(sched, task);
    return lua_yield(task->state, 1);
  }
}

static int lup_file_free(lua_State *L) {
  puts(__func__);
  lup_File *file = lua_touserdata(L, 1);
  if (file->buf) free(file->buf);
  return 0;
}

static int lup_sched_tostring(lua_State *L) {
  lup_Sched *sched = luaL_checkudata(L, 1, LUP_SCHED_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_SCHED_TNAME, sched);
  return 1;
}
static int lup_task_tostring(lua_State *L) {
  lup_Task *task = luaL_checkudata(L, 1, LUP_TASK_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_TASK_TNAME, task);
  return 1;
}
static int lup_file_tostring(lua_State *L) {
  lup_File *file = luaL_checkudata(L, 1, LUP_FILE_TNAME);
  lua_pushfstring(L, "userdata<%s>: %p", LUP_FILE_TNAME, file);
  return 1;
}

static luaL_Reg lup_Task_meths[] = {
  {"join",      lup_task_join},
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
  {"__gc",      lup_file_free},
  {"__tostring",lup_file_tostring},
  {NULL,        NULL}
};

int luaopen_kernel(lua_State *L) {
  lua_settop(L, 0);
  lup_Sched_new(L);
  __lup_default_sched = lua_touserdata(L, -1);
  lua_settop(L, 0);

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

