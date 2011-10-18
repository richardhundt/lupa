#!/usr/bin/env luajit

local __env=setmetatable({},{__index=_G});local self={};_G[("package")].path  = (";;./src/?.lua;./lib/?.lua;"..tostring(_G[("package")].path).."");
_G[("package")].cpath = (";;./lib/?.so;"..tostring(_G[("package")].cpath).."");

_G.newtable = __env.loadstring(("return {...}"));

local rawget, rawset = _G.rawget, _G.rawset;
local getmetatable, setmetatable = _G.getmetatable, _G.setmetatable;

_G.__class = function(into, name, _from, _with, body) 
    if (#(_from) )==( 0) then  
        _from[(#(_from) )+( 1)] = __env.Object;
     end 

    local _super = __env.newtable();
    local _class = __env.newtable();
    _class.__name = name;
    _class.__from = _from;

    local readers = __env.newtable();
    local writers = __env.newtable();

    _class.__readers = readers;
    _class.__writers = writers;

    local queue  = __env.newtable(__env.unpack(_from));
    while  (#(queue) )>( 0)  do local __break repeat 
        local base = __env.table.remove(queue, 1);
        if (getmetatable(base) )~=( __env.Class) then  
            __env.error(("TypeError: "..tostring(base).." is not a Class"), 2);
         end 
        _from[base] = (true);
        for k,v in __op_each(__env.pairs(base))  do local __break repeat 
            if (_class[k] )==( (nil)) then   _class[k] = v;  end 
            if (_super[k] )==( (nil)) then   _super[k] = v;  end 
         until true if __break then break end end 
        for k,v in __op_each(__env.pairs(base.__readers))  do local __break repeat 
            if (readers[k] )==( (nil)) then   readers[k] = v;  end 
         until true if __break then break end end 
        for k,v in __op_each(__env.pairs(base.__writers))  do local __break repeat 
            if (writers[k] )==( (nil)) then   writers[k] = v;  end 
         until true if __break then break end end 
        if base.__from then  
            for i=1, #(base.__from)  do local __break repeat 
                queue[(#(queue) )+( 1)] = base.__from[i];
             until true if __break then break end end 
         end 
     until true if __break then break end end 

    _class.__index = function(obj, key) 
        local reader = readers[key];
        if reader then    do return reader(obj) end  end 
         do return _class[key] end
     end;
    _class.__newindex = function(obj, key, val) 
        local writer = writers[key];
        if writer then  
            writer(obj, val);
        
        else 
            rawset(obj, key, val);
         end 
     end;
    _class.new = function(self,...) 
        local obj = setmetatable(__env.newtable(), self);
        if (rawget(self, ("__init")) )~=( (nil)) then  
            local ret = obj:__init(...);
            if (ret )~=( (nil)) then  
                 do return ret end
             end 
         end 
         do return obj end
     end;

    setmetatable(_class, __env.Class);

    local _env = setmetatable(Hash({ }), Hash({ __index = into }));
    if _with then  
        for i=1, #(_with)  do local __break repeat 
            _with[i]:compose(_env, _class);
         until true if __break then break end end 
     end 

    into[name] = _class;
    body(_env, _class, _super);

     do return _class end
 end;
_G.__trait = function(into, name, _with, body) 
    local _trait = __env.newtable();
    _trait.__name = name;
    _trait.__body = body;
    _trait.__with = _with;
    setmetatable(_trait, __env.Trait);
    if into then  
        into[name] = _trait;
     end 
     do return _trait end
 end;
_G.__object = function(into, name, _from, _with, body) 
    for i=1, #(_from)  do local __break repeat 
        if (getmetatable(_from[i]) )~=( __env.Class) then  
            _from[i] = getmetatable(_from[i]);
         end 
     until true if __break then break end end 
    local anon = __env.__class(into, (("#"))..(name), _from, _with, body);
    local inst = anon();
    into[name] = inst;
     do return inst end
 end;
_G.__method = function(into, name, code) 
    into[name] = code;
 end;
_G.__has = function(into, name, def) 
    local setter = (("__set_"))..(name);
    local getter = (("__get_"))..(name);
    into[setter] = function(obj, val) 
        do return rawset(obj, name, val) end
     end;
    into[getter] = function(obj) 
        local val = rawget(obj, name);
        if (val )==( (nil)) then  
            val = def(obj);
            obj[setter](obj, val);
         end 
         do return val end
     end;
 end;
_G.__grammar = function(into, name, body) 
   local gram = __env.newtable();
   local patt;
   function gram.match(self,...) 
       do return patt:match(...) end
    end
   local _env = setmetatable(Hash({ }), Hash({ __index = into }));
   body(_env, gram);
   do 
      local grmr = __env.newtable();
      for k,v in __op_each(__env.pairs(gram))  do local __break repeat 
         if (__env.__patt.type(v) )==( ("pattern")) then  
            grmr[k] = v;
          end 
       until true if __break then break end end 
      grmr[1] = (rawget(gram, 1) )or( ("__init"));
      patt = __env.__patt.P(grmr);
    end

   into[name] = gram;
    do return gram end
 end;
_G.__rule = function(into, name, patt) 
   if ((name )==( ("__init") ))or(( rawget(into,1) )==( (nil))) then  
      into[1] = name;
    end 
   into[name] = patt;
   local rule_name = (("__rule_"))..(name);
   into[(("__get_"))..(name)] = function(self) 
      local _rule = rawget(self, rule_name);
      if (_rule )==( (nil)) then  
         local grmr = __env.newtable();
         for k,v in __op_each(__env.pairs(self))  do local __break repeat 
            if (__env.__patt.type(v) )==( ("pattern")) then  
               grmr[k] = v;
             end 
          until true if __break then break end end 
         grmr[1] = name;
         _rule = __env.__patt.P(grmr);
         rawset(self, rule_name, _rule);
       end 
       do return _rule end
    end;
 end;

_G.__try = function(_try, _catch) 
    local ok, er = __env.pcall(_try);
    if not(ok) then   _catch(er);  end 
 end;

_G.__patt = __env.require(("lpeg"));
_G.__patt.setmaxstack(1024);
do 
   local function make_capt_hash(init) 
       do return function(tab) 
         if (init )~=( (nil)) then  
            for k,v in __op_each(init)  do local __break repeat 
               if (tab[k] )==( (nil)) then   tab[k] = v;  end 
             until true if __break then break end end 
          end 
          do return __op_as(tab , __env.Hash) end
       end end
    end
   local function make_capt_array(init) 
       do return function(tab) 
         if (init )~=( (nil)) then  
            for i=1, #(init)  do local __break repeat 
               if (tab[i] )==( (nil)) then   tab[i] = init[i];  end 
             until true if __break then break end end 
          end 
          do return __op_as(tab , __env.Array) end
       end end
    end

   __env.__patt.Ch = function(patt,init) 
       do return __env.Pattern.__div(__env.__patt.Ct(patt), make_capt_hash(init)) end
    end;
   __env.__patt.Ca = function(patt,init) 
       do return __env.Pattern.__div(__env.__patt.Ct(patt), make_capt_array(init)) end
    end;

   local predef = __env.newtable();

   predef.nl  = __env.__patt.P(("\n"));
   predef.pos = __env.__patt.Cp();

   local any = __env.__patt.P(1);
   __env.__patt.locale(predef);

   predef.a = predef.alpha;
   predef.c = predef.cntrl;
   predef.d = predef.digit;
   predef.g = predef.graph;
   predef.l = predef.lower;
   predef.p = predef.punct;
   predef.s = predef.space;
   predef.u = predef.upper;
   predef.w = predef.alnum;
   predef.x = predef.xdigit;
   predef.A = (any )-( predef.a);
   predef.C = (any )-( predef.c);
   predef.D = (any )-( predef.d);
   predef.G = (any )-( predef.g);
   predef.L = (any )-( predef.l);
   predef.P = (any )-( predef.p);
   predef.S = (any )-( predef.s);
   predef.U = (any )-( predef.u);
   predef.W = (any )-( predef.w);
   predef.X = (any )-( predef.x);

   __env.__patt.predef = predef;
   __env.__patt.Def = function(id) 
      if (predef[id] )==( (nil)) then  
         __env.error(("No predefined pattern '"..tostring(id).."'"), 2);
       end 
       do return predef[id] end
    end;
 end

_G.__main = _G;
_G.__main.__env = _G;

_G.__package = function(into, name, body, args) 
   local path = __env.newtable();
   for frag in __op_each(name:gmatch(("([^%.]+)")))  do local __break repeat 
      path[(#(path) )+( 1)] = frag;
    until true if __break then break end end 

   local pckg = _G.__main;
   for i=1, #(path)  do local __break repeat 
      local name = path[i];

      if (rawget(pckg, name) )==( (nil)) then  
         local pkg = __env.newtable();
         local env = __env.newtable();
         local env_meta = __env.newtable();
         local pkg_meta = __env.newtable();

         function env_meta.__index(env, key) 
            local val = pkg[key];
            if (val )~=( (nil)) then    do return val end  end 
             do return into.__env[key] end
          end
         function env_meta.__newindex(env, key, val) 
            rawset(env, key, val);
            do return rawset(pkg, key, val) end
          end

         function pkg_meta.__newindex(pkg, key, val) 
            env[key] = val;
          end

         setmetatable(env, env_meta);
         setmetatable(pkg, pkg_meta);

         pkg.__env = env;
         pckg[name] = pkg;
       end 
      pckg = pckg[name];
    until true if __break then break end end 
   into[name] = pckg;
   _G[("package")].loaded[name] = pckg;
   if body then  
      body(pckg.__env, pckg);
    end 
    do return pckg end
 end;

_G.__import = function(_from, what) 
   local mod = __env.__load(_from);
   local out = Array( );
   if what then  
      for i=1, #(what)  do local __break repeat 
         out[i] = mod[what[i]];
       until true if __break then break end end 
       do return __op_spread(out) end
   
   else 
       do return mod end
    end 
 end;
_G.__export = function(self,...) local what=Array(...);
    for i=1, #(what)  do local __break repeat 
        self.__export[what[i]] = (true);
     until true if __break then break end end 
 end;

_G.__load = function(_from) 
   local path = _from;
   if (__env.type(_from) )==( ("table")) then  
      path = __env.table.concat(_from, ("."));
    end 
   local mod = __env.require(path);
   if (mod )==( (true)) then  
      mod = _G;
      for i=1, #(_from)  do local __break repeat 
         mod = mod[_from[i]];
       until true if __break then break end end 
    end 
    do return mod end
 end;

_G.__op_as     = setmetatable;
_G.__op_typeof = getmetatable;
_G.__op_yield  = __env.coroutine[("yield")];
_G.__op_throw  = __env.error;

_G.__op_in = function(key, obj) 
    do return (rawget(obj, key) )~=( (nil)) end
 end;
_G.__op_like = function(this, that) 
   for k,v in __op_each(__env.pairs(that))  do local __break repeat 
      if (__env.type(this[k]) )~=( __env.type(v)) then  
          do return (false) end
       end 
      if not(this[k]:isa(getmetatable(v))) then  
          do return (false) end
       end 
    until true if __break then break end end 
    do return (true) end
 end;
_G.__op_spread = function(a) 
   local mt = getmetatable(a);
   local __spread = (mt )and( rawget(mt, ("__spread")));
   if __spread then    do return __spread(a) end  end 
    do return __env.unpack(a) end
 end;
_G.__op_each = function(a,...) 
   if (__env.type(a) )==( ("function")) then    do return a, ... end  end 
   local mt = getmetatable(a);
   local __each = (mt )and( rawget(mt, ("__each")));
   if __each then    do return __each(a) end  end 
    do return __env.pairs(a) end
 end;
_G.__op_lshift = function(a,b) 
   local mt = getmetatable(a);
   local __lshift = (mt )and( rawget(mt, ("__lshift")));
   if __lshift then    do return __lshift(a, b) end  end 
    do return __env.bit.lshift(a, b) end
 end;
_G.__op_rshift = function(a,b) 
   local mt = getmetatable(a);
   local __rshift = (mt )and( rawget(mt, ("__rshift")));
   if __rshift then    do return __rshift(a, b) end  end 
    do return __env.bit.rshift(a, b) end
 end;
_G.__op_arshift = function(a,b) 
   local mt = getmetatable(a);
   local __arshift = (mt )and( rawget(mt, ("__arshift")));
   if __arshift then    do return __arshift(a, b) end  end 
    do return __env.bit.arshift(a, b) end
 end;
_G.__op_bor = function(a,b) 
   local mt = getmetatable(a);
   local __bor = (mt )and( rawget(mt, ("__bor")));
   if __bor then    do return __bor(a, b) end  end 
    do return __env.bit.bor(a, b) end
 end;
_G.__op_bxor = function(a,b) 
   local mt = getmetatable(a);
   local __bxor = (mt )and( rawget(mt, ("__bxor")));
   if __bxor then    do return __bxor(a, b) end  end 
    do return __env.bit.bxor(a, b) end
 end;
_G.__op_bnot = function(a) 
   local mt = getmetatable(a);
   local __bnot = (mt )and( rawget(mt, ("__bnot")));
   if __bnot then    do return __bnot(a) end  end 
    do return __env.bit.bnot(a) end
 end;

_G.Type = __env.newtable();
__env.Type.__name = ("Type");
__env.Type.__call = function(self,...) 
    do return self:__apply(...) end
 end;
__env.Type.isa = function(self, that) 
    do return (getmetatable(self) )==( that) end
 end;
__env.Type.can = function(self, key) 
    do return (rawget(self, key) )or( rawget(getmetatable(self), key)) end
 end;
__env.Type.does = function(self, that) 
    do return (false) end
 end;
__env.Type.__index = __env.Type;
__env.Type.__tostring = function(self) 
    do return (("type "))..(((rawget(self, ("__name")) )or( ("Type")))) end
 end;

_G.Class = setmetatable(__env.newtable(), __env.Type);
__env.Class.__tostring = function(self) 
    do return self.__name end
 end;
__env.Class.__index = function(self, key) 
   do return __env.error(("AccessError: no such member '"..tostring(key).."' in "..tostring(self.__name)..""), 2) end
 end;
__env.Class.__newindex = function(self, key, val) 
    if key:match(("^__get_")) then  
        local _k = key:match(("^__get_(.-)$"));
        self.__readers[_k] = val;
    
     elseif key:match(("^__set_")) then  
        local _k = key:match(("^__set_(.-)$"));
        self.__writers[_k] = val;
     end 
    do return rawset(self, key, val) end
 end;
__env.Class.__call = function(self,...) 
    do return self:__apply(...) end
 end;

_G.Object = setmetatable(__env.newtable(), __env.Class);
__env.Object.__name = ("Object");
__env.Object.__from = __env.newtable();
__env.Object.__with = __env.newtable();
__env.Object.__readers = __env.newtable();
__env.Object.__writers = __env.newtable();
__env.Object.__tostring = function(self) 
    do return ("object "..tostring(getmetatable(self)).."") end
 end;
__env.Object.__index = __env.Object;
__env.Object.isa = function(self, that) 
   local meta = getmetatable(self);
    do return ((meta )==( that ))or( ((meta.__from )and( ((meta.__from[that] )~=( (nil)))))) end
 end;
__env.Object.can = function(self, key) 
   local meta = getmetatable(self);
    do return rawget(meta, key) end
 end;
__env.Object.does = function(self, that) 
    do return (self.__with[that.__body] )~=( (nil)) end
 end;

_G.Trait = setmetatable(__env.newtable(), __env.Type);
__env.Trait.__call = function(self,...) local args=Array(...);
   local copy = __env.__trait((nil), self.__name, self.__with, self.__body);
   local make = self.compose;
   copy.compose = function(self, into, recv) 
       do return make(self, into, recv, __op_spread(args)) end
    end;
    do return copy end
 end;
__env.Trait.__tostring = function(self) 
    do return (("trait "))..(self.__name) end
 end;
__env.Trait.__index = __env.Trait;
__env.Trait.compose = function(self, into, recv,...) 
   for i=1, #(self.__with)  do local __break repeat 
      self.__with[i]:compose(into, recv);
    until true if __break then break end end 
   self.__body(into, recv, ...);
   recv.__with[self.__body] = (true);
    do return into end
 end;

_G.Hash = setmetatable(__env.newtable(), __env.Type);
__env.Hash.__name = ("Hash");
__env.Hash.__index = __env.Hash;
__env.Hash.__apply = function(self, table) 
    do return setmetatable((table )or( __env.newtable()), self) end
 end;
__env.Hash.__tostring = function(self) 
   local buf = __env.newtable();
   for k, v in __op_each(__env.pairs(self))  do local __break repeat 
      local _v;
      if (__env.type(v) )==( ("string")) then  
         _v = __env.string.format(("%q"), v);
      
      else 
         _v = __env.tostring(v);
       end 
      if (__env.type(k) )==( ("string")) then  
         buf[(#(buf) )+( 1)] = ((k)..(("=")))..(_v);
      
      else 
         buf[(#(buf) )+( 1)] = ("["..tostring(k).."]="..tostring(_v).."");
       end 
    until true if __break then break end end 
    do return ((("{"))..(table.concat(buf, (","))))..(("}")) end
 end;
__env.Hash.__getitem = rawget;
__env.Hash.__setitem = rawset;
__env.Hash.__each = __env.pairs;

_G.Array = setmetatable(__env.newtable(), __env.Type);
__env.Array.__name = ("Array");
__env.Array.__index = __env.Array;
__env.Array.__apply = function(self,...) 
    do return setmetatable(__env.newtable(...), self) end
 end;
__env.Array.__tostring = function(self) 
   local buf = __env.newtable();
   for i=1, #(self)  do local __break repeat 
      if (__env.type(self[i]) )==( ("string")) then  
         buf[(#(buf) )+( 1)] = __env.string.format(("%q"), self[i]);
      
      else 
         buf[(#(buf) )+( 1)] = __env.tostring(self[i]);
       end 
    until true if __break then break end end 
    do return ((("["))..(table.concat(buf,(","))))..(("]")) end
 end;
__env.Array.__each = __env.ipairs;
__env.Array.__spread = __env.unpack;
__env.Array.__getitem = rawget;
__env.Array.__setitem = rawset;
__env.Array.unpack = __env.unpack;
__env.Array.insert = table.insert;
__env.Array.remove = table.remove;
__env.Array.concat = table.concat;
__env.Array.sort = table.sort;
__env.Array.each = function(self, block) 
   for i=1, #(self)  do local __break repeat  block(self[i]);  until true if __break then break end end 
 end;
__env.Array.map = function(self, block) 
   local out = __env.Array();
   for i=1, #(self)  do local __break repeat 
      local v = self[i];
      out[(#(out) )+( 1)] = block(v);
    until true if __break then break end end 
    do return out end
 end;
__env.Array.grep = function(self, block) 
   local out = __env.Array();
   for i=1, #(self)  do local __break repeat 
      local v = self[i];
      if block(v) then  
         out[(#(out) )+( 1)] = v;
       end 
    until true if __break then break end end 
    do return out end
 end;
__env.Array.push = function(self, v) 
   self[(#(self) )+( 1)] = v;
 end;
__env.Array.pop = function(self) 
   local v = self[#(self)];
   self[#(self)] = (nil);
    do return v end
 end;
__env.Array.shift = function(self) 
   local v = self[1];
   for i=2, #(self)  do local __break repeat 
      self[(i)-(1)] = self[i];
    until true if __break then break end end 
   self[#(self)] = (nil);
    do return v end
 end;
__env.Array.unshift = function(self, v) 
   for i=(#(self))+(1), 1, -(1)  do local __break repeat 
      self[i] = self[(i)-(1)];
    until true if __break then break end end 
   self[1] = v;
 end;
__env.Array.splice = function(self, offset, count,...) local args=Array(...);
   local out = __env.Array();
   for i=offset, ((offset )+( count ))-( 1)  do local __break repeat 
      out:push(self:remove(offset));
    until true if __break then break end end 
   for i=#(args), 1, -(1)  do local __break repeat 
      self:insert(offset, args[i]);
    until true if __break then break end end 
    do return out end
 end;
__env.Array.reverse = function(self) 
   local out = __env.Array();
   for i=1, #(self)  do local __break repeat 
      out[i] = self[(((#(self) )-( i)) )+( 1)];
    until true if __break then break end end 
    do return out end
 end;

_G.Range = setmetatable(__env.newtable(), __env.Type);
__env.Range.__name = ("Range");
__env.Range.__index = __env.Range;
__env.Range.__apply = function(self, min, max, inc) 
   min = __env.assert(__env.tonumber(min), ("range min is not a number"));
   max = __env.assert(__env.tonumber(max), ("range max is not a number"));
   inc = __env.assert(__env.tonumber((inc )or( 1)), ("range inc is not a number"));
    do return setmetatable(__env.newtable(min, max, inc), self) end
 end;
__env.Range.__each = function(self) 
   local inc = self[3];
   local cur = (self[1] )-( inc);
   local max = self[2];
    do return function() 
      cur = (cur )+( inc);
      if (cur )<=( max) then  
          do return cur end
       end 
    end end
 end;
__env.Range.each = function(self, block) 
   for i in __op_each(__env.Range:__each(self))  do local __break repeat 
      block(i);
    until true if __break then break end end 
 end;

_G.Nil = setmetatable(__env.newtable(), __env.Type);
__env.Nil.__name = ("Nil");
__env.Nil.__index = function(self, key) 
    local val = __env.Type[key];
    if (val )==( (nil)) then  
        __env.error(("TypeError: no such member "..tostring(key).." in type Nil"), 2);
     end 
     do return val end
 end;
__env.debug.setmetatable((nil), __env.Nil);

_G.Number = setmetatable(__env.newtable(), __env.Type);
__env.Number.__name = ("Number");
__env.Number.__index = __env.Number;
__env.Number.__apply = function(self, val) 
    local v = __env.tonumber(val);
    if (v )==( (nil)) then  
        __env.error(("TypeError: cannot coerce '"..tostring(val).."' to Number"), 2);
     end 
     do return v end
 end;
__env.Number.times = function(self, block) 
   for i=1, self  do local __break repeat  block(i);  until true if __break then break end end 
 end;
__env.debug.setmetatable(0, __env.Number);

_G.String = setmetatable(__env.string, __env.Type);
__env.String.__name = ("String");
__env.String.__index = __env.String;
__env.String.__apply = function(self, val) 
     do return __env.tostring(val) end
 end;
__env.String.__match = function(a,p) 
    do return __env.__patt.P(p):match(a) end
 end;
__env.String.split = function(str, sep, max) 
   if not(str:find(sep)) then  
       do return __env.Array(str) end
    end 
   if ((max )==( (nil) ))or((  max )<( 1)) then  
      max = 0;
    end 
   local pat = ((("(.-)"))..(sep))..(("()"));
   local idx = 0;
   local list = __env.Array();
   local last;
   for part, pos in __op_each(str:gmatch(pat))  do local __break repeat 
      idx = (idx )+( 1);
      list[idx] = part;
      last = pos;
      if (idx )==( max) then   do __break = true; break end  end 
    until true if __break then break end end 
   if (idx )~=( max) then  
      list[(idx )+( 1)] = str:sub(last);
    end 
    do return list end
 end;
__env.debug.setmetatable((""), __env.String);

_G.Boolean = setmetatable(__env.newtable(), __env.Type);
__env.Boolean.__name = ("Boolean");
__env.Boolean.__index = __env.Boolean;
__env.debug.setmetatable((true), __env.Boolean);

_G.Function = setmetatable(__env.newtable(), __env.Type);
__env.Function.__name = ("Function");
__env.Function.__index = __env.Function;
__env.Function.__apply = function(self, code, fenv) 
    code = __env.Lupa:compile(code);
    local func = __env.assert(__env.loadstring(code, ("=eval")));
    if fenv then  
        __env.setfenv(func, fenv);
     end 
     do return func end
 end;
__env.debug.setmetatable(function()   end, __env.Function);

_G.Coroutine = setmetatable(__env.newtable(), __env.Type);
__env.Coroutine.__name = ("Coroutine");
__env.Coroutine.__index = __env.Coroutine;
for k,v in __op_each(__env.pairs(__env.coroutine))  do local __break repeat 
   __env.Coroutine[k] = v;
 until true if __break then break end end 
__env.debug.setmetatable(__env.coroutine.create(function()   end), __env.Coroutine);

_G.Pattern = setmetatable(getmetatable(__env.__patt.P(1)), __env.Type);
__env.Pattern.__call = function(patt, subj) 
    do return patt:match(subj) end
 end;
__env.Pattern.__match = function(patt, subj) 
    do return patt:match(subj) end
 end;

self.Lupa=__class(__env,"Lupa",{},{},function(__env,self,super) 

    self.Scope=__class(__env,"Scope",{},{},function(__env,self,super) 
        __has(self,"entries",function(self) return Hash({ }) end);
        __has(self,"outer",function(self) return _G end);
        __method(self,"__init",function(self,outer) 
            self.outer = outer;
         end);
        __method(self,"lookup",function(self,name) 
            if __op_in(name , self.entries) then  
                 do return self.entries[name] end
            
             elseif __op_in(("outer") , self) then  
                 do return self.outer:lookup(name) end
             end 
         end);
        __method(self,"define",function(self,name, info) 
            self.entries[name] = info;
         end);
     end);

    self.Context=__class(__env,"Context",{},{},function(__env,self,super) 
        __has(self,"scope",function(self) return __env.Lupa.Scope:new() end);
        __method(self,"enter",function(self) 
            self.scope = __env.Lupa.Scope:new(self.scope);
         end);
        __method(self,"leave",function(self) 
            if __op_in(("outer") , self.scope) then  
               local outer = self.scope.outer;
               self.scope = outer;
                do return outer end
             end 
            do return __env.error(("no outer scope")) end
         end);
        __method(self,"define",function(self,name, info) 
            do return self.scope:define(name, (info )or( Hash({ }))) end
         end);
        __method(self,"lookup",function(self,name) 
            do return self.scope:lookup(name) end
         end);
     end);

    self.Grammar=__grammar(__env,"Grammar",function(__env,self) 

        local function error_line(src, pos) 
            local line = 1;
            local index, limit = 1, pos;
            while (index )<=( limit)  do local __break repeat 
                local s, e = src:find(("\n"), index, (true));
                if ((s )==( (nil) ))or(( e )>( limit)) then   do __break = true; break end  end 
                index = (e )+( 1);
                line  = (line )+( 1);
             until true if __break then break end end 
             do return line end
         end
        local function error_near(src, pos) 
            if ((#(src) )<(( pos )+( 20))) then  
                 do return src:sub(pos) end
            
            else 
                 do return (src:sub(pos, (pos )+( 20)))..(("...")) end
             end 
         end
        local function syntax_error(m) 
             do return function(src, pos) 
                local line, near = error_line(src, pos), error_near(src, pos);
                do return __env.error(("SyntaxError: "..tostring((m)or((""))).." on line "..tostring(line).." near '"..tostring(near).."'")) end
             end end
         end

        local id_counter = 9;
        local function genid() 
            id_counter=(id_counter)+(1);
             do return (("_"))..(id_counter) end
         end

        local function quote(c)  do return ("%q"):format(c) end  end

        local nl      = __patt.P( __patt.P(("\n")) );
        local comment = __patt.P( __patt.Cs(
             ((-nl* __patt.Def("s"))^0* ((__patt.P(("//")) )/( ("--")))* (-nl* __patt.P(1))^0* nl)
            + ((__patt.P(("/*")) )/( ("--[=[")))* ((__patt.P(("]=]")) )/( ("]\\=]")) + -__patt.P(("*/"))* __patt.P(1))^0* ((__patt.P(("*/")) )/( ("]=]")))
        ) );
        local idsafe  = __patt.P( -(__patt.Def("alnum") + __patt.P(("_"))) );
        local s       = __patt.P( (comment + __patt.Def("s"))^0 );
        local semicol = __patt.P( ((__patt.P((";")) )/( ("")))^-1 );
        local digits  = __patt.P( (__patt.Def("digit")* __patt.Cs( (__patt.P(("_")) )/( ("")) )^-1)^1 );
        local keyword = __patt.P( (
              __patt.P(("var")) + __patt.P(("function")) + __patt.P(("class")) + __patt.P(("with")) + __patt.P(("like")) + __patt.P(("in"))
            + __patt.P(("nil")) + __patt.P(("true")) + __patt.P(("false")) + __patt.P(("typeof")) + __patt.P(("return")) + __patt.P(("as"))
            + __patt.P(("for")) + __patt.P(("throw")) + __patt.P(("method")) + __patt.P(("has")) + __patt.P(("from")) + __patt.P(("break"))
            + __patt.P(("continue")) + __patt.P(("package")) + __patt.P(("import")) + __patt.P(("try")) + __patt.P(("catch"))
            + __patt.P(("finally")) + __patt.P(("if")) + __patt.P(("else")) + __patt.P(("yield")) + __patt.P(("grammar")) + __patt.P(("rule"))
        )* idsafe );

        local prec = Hash({
            [("^^")]  = 4,
            [("*")]   = 5,
            [("/")]   = 5,
            [("%")]   = 5,
            [("+")]   = 6,
            [("-")]   = 6,
            [("~")]   = 6,
            [(">>")]  = 7,
            [("<<")]  = 7,
            [(">>>")] = 7,
            [("<=")]  = 8,
            [(">=")]  = 8,
            [("<")]   = 8,
            [(">")]   = 8,
            [("in")]  = 8,
            [("as")]  = 8,
            [("==")]  = 9,
            [("!=")]  = 9,
            [("&")]   = 10,
            [("^")]   = 11,
            [("|")]   = 12,
            [("&&")]  = 13,
            [("||")]  = 14,
        });

        local unrops = Hash({
            [("!")] = ("not(%s)"),
            [("#")] = ("#(%s)"),
            [("-")] = ("-(%s)"),
            [("~")] = ("__op_bnot(%s)"),
            [("@")] = ("__op_spread(%s)"),
            [("throw")] = ("__op_throw(%s)"),
            [("typeof")] = ("__op_typeof(%s)"),
        });

        local binops = Hash({
            [("^^")] = ("(%s)^(%s)"),
            [("*")] = ("(%s)*(%s)"),
            [("/")] = ("(%s)/(%s)"),
            [("%")] = ("(%s)%%(%s)"),
            [("+")] = ("(%s)+(%s)"),
            [("-")] = ("(%s)-(%s)"),
            [("~")] = ("(%s)..(%s)"),
            [(">>")] = ("__op_rshift(%s,%s)"),
            [("<<")] = ("__op_lshift(%s,%s)"),
            [(">>>")] = ("__op_arshift(%s,%s)"),
            [("<=")] = ("(%s)<=(%s)"),
            [(">=")] = ("(%s)>=(%s)"),
            [("<")] = ("(%s)<(%s)"),
            [(">")] = ("(%s)>(%s)"),
            [("in")] = ("__op_in(%s,%s)"),
            [("as")] = ("__op_as(%s,%s)"),
            [("==")] = ("(%s)==(%s)"),
            [("!=")] = ("(%s)~=(%s)"),
            [("&")] = ("__op_band(%s,%s)"),
            [("^")] = ("__op_bxor(%s,%s)"),
            [("|")] = ("__op_bor(%s,%s)"),
            [("&&")] = ("(%s)and(%s)"),
            [("||")] = ("(%s)or(%s)"),
        });

        local function fold_prefix(o,e) 
            if ((o )==( ("#") ))and( e:match(("^%s*%.%.%.%s*$"))) then  
                 do return ("select(\"#\",...)") end
             end 
             do return unrops[o]:format(e) end
         end

        --/*
        local function fold_infix(e) 
            local s = Array( e[1] );
            for i=2, #(e)  do local __break repeat 
                s[(#(s) )+( 1)] = e[i];
                while (not(binops[s[#(s)]]) )and( s[(#(s) )-( 1)])  do local __break repeat 
                    local p = s[(#(s) )-( 1)];
                    local n = e[(i )+( 1)];
                    if ((n )==( (nil) ))or(( prec[p] )<=( prec[n])) then  
                        local b, o, a = s:pop(), s:pop(), s:pop();
                        if not(binops[o]) then  
                            __env.error(("bad expression: "..tostring(e)..", stack: "..tostring(s)..""));
                         end 
                        s:push(binops[o]:format(a, b));
                    
                    else 
                        do __break = true; break end
                     end 
                 until true if __break then break end end 
             until true if __break then break end end 
             do return s[1] end
         end
        --*/

        --[=[ enable for recursive descent expr parsing
        function fold_infix(a,o,b) {
            return binops[o].format(a,b)
        }
        //]=]

        local function make_binop_bind(a, o, b) 
             do return ((a)..(("=")))..(binops[o]:format(a,b)) end
         end

        local function make_params(p) 
            local h = ("");
            if ((#(p) )>( 0 ))and( p[#(p)]:find(("..."), 1, (true))) then  
                local r = p[#(p)];
                local n = r:match(("%.%.%.([%w_0-9]+)"));
                p[#(p)] = ("...");
                if n then  
                    h = ("local %s=Array(...);"):format(n);
                 end 
             end 
             do return p:concat((",")), h end
         end

        local function make_func(p,b) 
            local p, h = make_params(p);
             do return ("function(%s) %s%s end"):format(p,h,b) end
         end

        local function make_short_func(p,b) 
            if (#(p) )==( 0) then   p:push(("_"));  end 
            local p, h = make_params(p);
             do return ("function(%s) %s%s end"):format(p,h,b) end
         end

        local function make_func_decl(c,n,p,b,s) 
            local p, h = make_params(p);
            if ((s )==( ("lexical") ))and(( #(n) )==( 1)) then  
                c:define(n[1]);
                 do return ("local function %s(%s) %s%s end"):format(n[1],p,h,b) end
            
             elseif (#(n) )==( 1) then  
                 do return ("function __env.%s(%s) %s%s end"):format(n[1],p,h,b) end
             end 
             do return ("function %s(%s) %s%s end"):format(n:concat((".")),p,h,b) end
         end

        local function make_meth_decl(ctx,n,p,b) 
            p:unshift(("self"));
            local p, h = make_params(p);
             do return ("__method(self,%q,function(%s) %s%s end);"):format(n,p,h,b) end
         end

        local function make_trait_decl(n,p,w,b) 
            local p, h = make_params(p);
            
                do return ("self.%s=__trait(__env,%q,{%s},function(__env,self,%s) %s%s end);")
                :format(n,n,w,p,h,b) end
         end

        local function make_try_stmt(try_body, catch_args, catch_body) 
             do return (
                (((("do local __return;"))..(
                ("__try(function() %s end,function(%s) %s end);") ))..(
                ("if __return then return __op_spread(__return) end")))..(
                (" end"))
            ):format(try_body, (catch_args )or( ("")), (catch_body )or( (""))) end
         end

        local function make_import_stmt(n,f) 
            local q = Array( );
            for i=1, #(n)  do local __break repeat  q[i] = quote(n[i]);  until true if __break then break end end 
             do return ("local %s=__import(%q,{%s});"):format(n:concat((",")), f, q:concat((","))) end
         end
        local function make_export_stmt(n) 
            local b = Array( );
            for i=1, #(n)  do local __break repeat 
                local q = quote(n[i]);
                b[i] = ("__export[%s]=true;"):format(q);
             until true if __break then break end end 
             do return b:concat(("")) end
         end
        local function define(name, ctx, base) 
            ctx:define(name, Hash({ base = base }));
             do return name end
         end
        local function define_const(name, ctx) 
            ctx:define(name);
             do return ("") end
         end
        local function enter(ctx) 
            ctx:enter();
             do return ("") end
         end
        local function leave(ctx) 
            ctx:leave();
             do return ("") end
         end
        local function define_pname(pname, ctx) 
            local name = pname[1];
            ctx:define(name, ("__env"));
             do return quote(pname:concat(("."))) end
         end
        local function lookup(name, ctx) 
            local info = ctx:lookup(name);
            if info then  
                if info.base then    do return ((info.base)..((".")))..(name) end  end 
                 do return name end
             end 
             do return (("__env."))..(name) end
         end
        local function lookup_or_define(name, ctx) 
            local info = ctx:lookup(name);
            if not(info) then  
                define(name, ctx, ("__env"));
                 do return (("__env."))..(name) end
             end 
            if info.base then  
                 do return ((info.base)..((".")))..(name) end
             end 
             do return name end
         end

        __rule(self,"__init",
            __patt.Cs( __patt.V("unit") )* (-__patt.P(1) + __patt.P(syntax_error(("expected <EOF>"))))
        );
        __rule(self,"unit",
            __patt.Cg( __patt.Cc((false)),"set_return")*
            __patt.Cg( __patt.Cc(("global")),"scope")*
            __patt.C( __patt.Def("s")^0* __patt.P(("#!"))* (-nl* __patt.P(1))^0* __patt.Def("s")^0 )^-1* s*
            __patt.Cc(("local __env=setmetatable({},{__index=_G});local self={};"))*
            ((__patt.Carg(1) )/( enter))*
            __patt.Cs( (s* __patt.V("main_body_stmt"))^0* s )*
            ((__patt.Carg(1) )/( leave))
        );
        __rule(self,"main_body_stmt",
             __patt.V("var_decl")
            + __patt.V("func_decl")
            + __patt.V("class_decl")
            + __patt.V("trait_decl")
            + __patt.V("object_decl")
            + __patt.V("grammar_decl")
            + __patt.V("package_decl")
            + __patt.V("import_stmt")
            + __patt.V("statement")
        );
        __rule(self,"statement",
             __patt.V("if_stmt")
            + __patt.V("try_stmt")
            + __patt.V("for_stmt")
            + __patt.V("for_in_stmt")
            + __patt.V("do_while_stmt")
            + __patt.V("while_stmt")
            + __patt.V("break_stmt")
            + __patt.V("continue_stmt")
            + __patt.V("yield_stmt")
            + __patt.V("block_stmt")
            + __patt.V("bind_stmt")
            + __patt.V("call_stmt")
        );
        __rule(self,"call_stmt",
            __patt.Cs( (__patt.Cs( __patt.V("primary")* s* (
                __patt.V("invoke_expr") + __patt.P(syntax_error(("expected <invoke_expr>")) )
            ) ) )/( ("%1;"))* semicol )
        );
        __rule(self,"return_stmt",
            __patt.Cs( (__patt.P(("return")) )/( (""))* idsafe* s* (
            __patt.Cb("set_return")* ((__patt.V("expr_list") + __patt.Cc((""))) )/( function(l,e) 
                if l then  
                     do return ("do __return = {%s}; return end"):format(e) end
                 end 
                 do return ("do return %s end"):format(e) end
             end)) )
        );
        __rule(self,"yield_stmt",
            __patt.P(("yield"))* idsafe* (__patt.Cs( s* __patt.V("expr_list") ) )/( ("__op_yield(%1);"))* semicol
        );
        __rule(self,"break_stmt",
            __patt.Cs( (__patt.C( __patt.P(("break"))* idsafe ) )/( ("do __break = true; break end")) )
        );
        __rule(self,"continue_stmt",
            __patt.Cs( (__patt.C( __patt.P(("continue"))* idsafe ) )/( ("do break end")) )
        );
        __rule(self,"if_stmt",
            __patt.Cs(
            __patt.P(("if"))* idsafe* s* __patt.V("expr")* __patt.Cc((" then "))* s* __patt.V("block")* (
                (s* ((__patt.C(__patt.P(("else"))* idsafe* s* __patt.P(("if"))* idsafe) )/( (" elseif")))* s*
                    __patt.V("expr")* __patt.Cc((" then "))* s* __patt.V("block")
                )^0*
                (s* __patt.P(("else"))* idsafe* s* __patt.V("block")* __patt.Cc((" end ")) + __patt.Cc((" end ")))
            )
            )
        );
        __rule(self,"try_stmt",
            __patt.Cs(
            __patt.P(("try"))* idsafe* s* __patt.P(("{"))* __patt.Cs( __patt.V("lambda_body")* s )*
            (__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) ))*
            ((s* __patt.P(("catch"))* idsafe* s* __patt.P(("("))* s* __patt.V("name")* s* __patt.P((")"))* s* __patt.P(("{"))* __patt.Cs( __patt.V("lambda_body")* s )* __patt.P(("}")))^-1
            )/( make_try_stmt)
            )
        );
        __rule(self,"import_stmt",
            __patt.Cs( ((__patt.P(("import"))* idsafe* s*
               __patt.Ca( __patt.V("param")* (s* __patt.P((","))* s* __patt.V("param"))^0 )* s* __patt.P(("from"))* s* __patt.V("qname")
            ) )/( make_import_stmt) )
        );
        __rule(self,"export_stmt",
            __patt.Cs( __patt.P(("export"))* idsafe* s* (__patt.Ca( __patt.V("name_list") ) )/( make_export_stmt) )
        );
        __rule(self,"for_stmt",
            __patt.Cs( __patt.P(("for"))* idsafe* s* __patt.V("param")* s* __patt.P(("="))* s* __patt.V("expr")* s* __patt.P((","))* s* __patt.V("expr")*
                (s* __patt.P((","))* s* __patt.V("expr"))^-1* s* __patt.V("loop_body")
            )
        );
        __rule(self,"for_in_stmt",
            __patt.Cs( __patt.P(("for"))* idsafe* s* __patt.V("param")* (s* __patt.P((","))* s* __patt.V("param"))^0* s* __patt.P(("in"))* idsafe* s*
                ((__patt.V("expr") )/( ("__op_each(%1)")))* s* __patt.V("loop_body")
            )
        );
        __rule(self,"while_stmt",
            __patt.Cs( __patt.P(("while"))* idsafe* s* __patt.V("expr")* s* __patt.V("loop_body") )
        );
        __rule(self,"do_while_stmt",
            __patt.Cs(
               __patt.P(("do"))* idsafe* __patt.Cs( s* __patt.V("loop_body")* s )*
               __patt.P(("while"))* idsafe* (__patt.Cs( s* __patt.V("expr") ) )/( ("repeat %1 until not(%2)"))
            )
        );
        __rule(self,"loop_body",
            ((__patt.P(("{")) )/( (" do local __break repeat ")))* __patt.V("block_body")* s*
            (
                ((__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) ))
                )/( (" until true if __break then break end end "))
            )
        );
        __rule(self,"block",
            __patt.Cs( ((__patt.P(("{")) )/( ("")))* __patt.V("block_body")* s* (((__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) )) )/( (""))) )
        );
        __rule(self,"block_stmt",
            __patt.Cs( ((__patt.P(("{")) )/( ("do ")))* __patt.V("block_body")* s* (((__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) )) )/( (" end"))) )
        );
        __rule(self,"block_body",
            __patt.Cg( __patt.Cc(("lexical")),"scope")*
            (s* __patt.V("block_body_stmt"))^0
        );
        __rule(self,"block_body_stmt",
             __patt.V("var_decl")
            + __patt.V("func_decl")
            + __patt.V("return_stmt")
            + __patt.V("statement")
        );
        __rule(self,"lambda_body",
            __patt.Cg( __patt.Cc((true)),"set_return")*
            __patt.V("block_body")* s
        );

        __rule(self,"var_decl",
            (__patt.Cs( __patt.P(("var"))* (idsafe )/( ("local"))* s*
                __patt.V("var_list")* (s* __patt.P(("="))* s* __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0)^-1
            ) )/( ("%1;"))* semicol
        );
        __rule(self,"var_list",
            (__patt.V("name")* (__patt.Carg(1) )/( define))* (s* __patt.P((","))* s* (__patt.V("name")* (__patt.Carg(1) )/( define)))^0
            --<name> (s "," s <name>)*
        );
        __rule(self,"slot_decl",
            __patt.Cs( ((__patt.P(("has"))* idsafe* s* __patt.V("name")* (s* __patt.P(("="))* s* __patt.V("expr") + __patt.Cc(("")))* semicol)
                )/( ("__has(self,\"%1\",function(self) return %2 end);"))
            )
        );
        __rule(self,"meth_decl",
            __patt.Cs( ((__patt.P(("method"))* idsafe* __patt.Carg(1)* s* __patt.V("param")* s*
            __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")"))* s* __patt.P(("{"))*
                __patt.Cs( __patt.V("func_body")* s )*
            __patt.P(("}"))) )/( make_meth_decl) )
        );
        __rule(self,"func_decl",
            __patt.Cs( ((__patt.P(("function"))* idsafe* __patt.Carg(1)*
            s* __patt.Ca( __patt.V("name")* (s* __patt.P(("."))* s* __patt.V("name"))^0 )* s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")"))* s* __patt.P(("{"))*
                __patt.Cs( __patt.V("func_body")* s )*
            __patt.P(("}"))* __patt.Cb("scope")) )/( make_func_decl) )
        );
        __rule(self,"func_body",
            __patt.Cg( __patt.Cc(("lexical")),"scope")*
            (s* __patt.V("func_body_stmt"))^0
        );
        __rule(self,"func_body_stmt",
             __patt.V("var_decl")
            + __patt.V("func_decl")
            + __patt.V("return_stmt")
            + __patt.V("block_stmt")
            + (__patt.V("expr")* (#(s* __patt.P(("}"))) )/( ("do return %1 end")))
            + __patt.V("statement")
        );
        __rule(self,"func",
            __patt.Cs( ((__patt.P(("function"))* idsafe* s*
            __patt.P(("("))* s* __patt.V("param_list")* s* (__patt.P((")")) + __patt.P( syntax_error(("expected ')'")) ))* s* __patt.P(("{"))*
                __patt.Cs( __patt.V("func_body")* s )*
            (__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) )))
            )/( make_func) )
        );
        __rule(self,"short_func",
            ((__patt.P((":")) )/( ("")))*
            ((s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")")) + __patt.Cc(Array(("_"))))* s* __patt.P(("{"))* __patt.Cs( __patt.V("func_body")* s )* (__patt.P(("}"))
            )/( make_short_func))* __patt.Cc((")"))
        );
        __rule(self,"package_decl",
            __patt.P(("package"))* idsafe* s* __patt.Cs( __patt.V("pname")* (__patt.Carg(1) )/( define_pname) )* s*
            __patt.P(("{"))*
                __patt.Cs( (s* __patt.V("main_body_stmt"))^0* s )*
            ((__patt.P(("}")) + __patt.P( syntax_error(("expected '}'")) ))
            )/( ("_G.package.loaded[%1]=__package(__env,%1,function(__env,self) %2 end);"))
        );
        __rule(self,"class_decl",
            __patt.P(("class"))* idsafe* s* __patt.Cs( __patt.V("name")* __patt.Carg(1)* (__patt.Cc(("__env")) )/( define) )* s*
            (__patt.V("class_from") + __patt.Cc(("")))* s*
            (__patt.V("class_with") + __patt.Cc(("")))* s*
            __patt.P(("{"))* __patt.Cs( __patt.V("class_body")* s )* (__patt.P(("}"))
            )/( ("self.%1=__class(__env,\"%1\",{%2},{%3},function(__env,self,super) %4 end);"))
        );
        __rule(self,"trait_decl",
            __patt.P(("trait"))* idsafe* s* __patt.Cs( __patt.V("name")* __patt.Carg(1)* (__patt.Cc(("__env")) )/( define) )* s*
            (__patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")")) + __patt.Cc(("..."))* __patt.Cc(("")))* s*
            (__patt.V("class_with") + __patt.Cc(("")))* s*
            __patt.P(("{"))* __patt.Cs( __patt.V("class_body")* s )* (__patt.P(("}"))
            )/( make_trait_decl)
        );
        __rule(self,"object_decl",
            __patt.P(("object"))* idsafe* s* __patt.Cs( __patt.V("name")* __patt.Carg(1)* (__patt.Cc(("__env")) )/( define) )* s*
            (__patt.V("class_from") + __patt.Cc(("")))* s*
            (__patt.V("class_with") + __patt.Cc(("")))* s*
            __patt.P(("{"))* __patt.Cs( __patt.V("class_body")* s )* (__patt.P(("}"))
            )/( ("self.%1=__object(__env,\"%1\",{%2},{%3},function(__env,self,super) %4 end);"))
        );
        __rule(self,"class_body",
            __patt.Cg( __patt.Cc(("lexical")),"scope")*
            ((__patt.Carg(1) )/( enter))*
            (__patt.Cc(("super"))* (__patt.Carg(1) )/( define_const))*
            __patt.Cs( (s* __patt.V("class_body_stmt"))^0 )*
            ((__patt.Carg(1) )/( leave))
        );
        __rule(self,"class_from",
            __patt.P(("from"))* idsafe* s* __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
        );
        __rule(self,"class_with",
            __patt.P(("with"))* idsafe* s* __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
        );
        __rule(self,"class_body_stmt",
             __patt.V("var_decl")
            + __patt.V("slot_decl")
            + __patt.V("func_decl")
            + __patt.V("meth_decl")
            + __patt.V("class_decl")
            + __patt.V("trait_decl")
            + __patt.V("object_decl")
            + __patt.V("grammar_decl")
            + __patt.V("statement")
        );
        __rule(self,"rest",
            __patt.Cs( __patt.C(__patt.P(("...")))* __patt.V("param")^-1 )
        );
        __rule(self,"stack",
            __patt.Cs(
             ((__patt.P(("..."))* s* __patt.P(("["))* s* __patt.V("expr")* s* (__patt.P(("]")) + __patt.P( syntax_error(("expected ']'")) ))) )/( ("select(%1,...)"))
            + __patt.C(__patt.P(("...")))
            )
        );
        __rule(self,"param_list",
            __patt.Ca(
             __patt.Cs( __patt.V("param")* s )* (__patt.P((","))* __patt.Cs( s* __patt.V("param")* s ))^0* (__patt.P((","))* __patt.Cs( s* __patt.V("rest")* s ))^-1
            + __patt.V("rest")
            + __patt.Cc((nil))
            )
        );
        __rule(self,"ident",
            __patt.Cs( __patt.V("name")* (__patt.Carg(1) )/( lookup) )
        );
        __rule(self,"param",
            __patt.V("name")* (__patt.Carg(1) )/( define)
        );
        __rule(self,"name",
            __patt.C( -keyword* ((__patt.Def("alpha") + __patt.P(("_")))* (__patt.Def("alnum") + __patt.P(("_")))^0) )
        );
        __rule(self,"name_list",
            __patt.Cs( __patt.V("name")* (s* __patt.P((","))* s* __patt.V("name"))^0 )
        );
        __rule(self,"qname",
            __patt.Cs( __patt.V("ident")* (__patt.P(("."))* __patt.V("name"))^0 )
        );
        __rule(self,"pname",
            __patt.Ca( __patt.V("name")* (__patt.P(("."))* __patt.V("name"))^0 )
        );
        __rule(self,"hexadec",
            __patt.P(("-"))^-1* __patt.P(("0x"))* __patt.Def("xdigit")^1
        );
        __rule(self,"decimal",
            __patt.P(("-"))^-1* digits* (__patt.P(("."))* digits)^-1* ((__patt.P(("e"))+__patt.P(("E")))* __patt.P(("-"))^-1* digits)^-1
        );
        __rule(self,"number",
            __patt.Cs( __patt.V("hexadec") + __patt.V("decimal") )
        );
        __rule(self,"string",
            (__patt.Cs( (__patt.V("qstring") + __patt.V("astring")) ) )/( ("(%1)"))
        );
        __rule(self,"special",
            __patt.Cs(
             (__patt.P(("\n"))  )/( ("\\\n"))
            + (__patt.P(("\\$")) )/( ("$"))
            + __patt.P(("\\\\"))
            + __patt.P(("\\"))* __patt.P(1)
            )
        );
        __rule(self,"qstring",
             (__patt.P(("\"\"\"")) )/( ("\""))* __patt.Cs( (
                 __patt.V("string_expr")
                + __patt.Cs( (__patt.V("special") + -__patt.P(("\"\"\""))*((__patt.P(("\"")) )/( ("\\\""))) + -(__patt.V("string_expr") + __patt.P(("\"\"\"")))* __patt.P(1))^1 )
            )^0 )* ((__patt.P(("\"\"\"")) )/( ("\"")) + __patt.P( syntax_error(("expected '\"\"\"'")) ))
            + __patt.P(("\""))* __patt.Cs( (
                 __patt.V("string_expr")
                + __patt.Cs( (__patt.V("special") + -(__patt.V("string_expr") + __patt.P(("\"")))* __patt.P(1))^1 )
            )^0 )* (__patt.P(("\"")) + __patt.P( syntax_error(("expected '\"'")) ))
        );
        __rule(self,"astring",
            (__patt.Cs(
                 ((__patt.P(("'''")) )/( ("")))* (__patt.P(("\\\\")) + __patt.P(("\\'")) + (-__patt.P(("'''"))* __patt.P(1)))^0* ((__patt.P(("'''")) )/( ("")))
                + ((__patt.P(("'"))   )/( ("")))* (__patt.P(("\\\\")) + __patt.P(("\\'")) + (-__patt.P(("'"))*   __patt.P(1)))^0* ((__patt.P(("'"))   )/( ("")))
            ) )/( quote)
        );
        __rule(self,"string_expr",
            ((__patt.P(("${")) )/( ("\"..")))* __patt.Cs( s* ((__patt.V("expr") )/( ("tostring(%1)")))* s )* ((__patt.P(("}")) )/( ("..\"")))
        );
        __rule(self,"vnil",
            __patt.Cs( __patt.C( __patt.P(("nil")) )* (idsafe )/( ("(nil)")) )
        );
        __rule(self,"vtrue",
            __patt.Cs( __patt.C( __patt.P(("true")) )* (idsafe )/( ("(true)")) )
        );
        __rule(self,"vfalse",
            __patt.Cs( __patt.C( __patt.P(("false")) )* (idsafe )/( ("(false)")) )
        );
        __rule(self,"range",
            __patt.Cs( ((
                __patt.P(("["))* s* __patt.V("expr")* s* __patt.P((":"))* s* __patt.V("expr")* ( s* __patt.P((":"))* s* __patt.V("expr") + __patt.Cc(("1")) )* s* __patt.P(("]"))
            ) )/( ("Range(%1,%2,%3)")) )
        );
        __rule(self,"array",
            __patt.Cs(
                ((__patt.P(("[")) )/( ("Array(")))* s*
                (__patt.V("array_elements") + __patt.Cc(("")))* s*
                ((__patt.P(("]")) )/( (")")) + __patt.P(syntax_error(("expected ']'"))))
            )
        );
        __rule(self,"array_elements",
            __patt.V("expr")* ( s* __patt.P((","))* s* __patt.V("expr") )^0* (s* __patt.P((",")))^-1
        );
        __rule(self,"hash",
            __patt.Cs(
                ((__patt.P(("{")) )/( ("Hash({")))* s*
                (__patt.V("hash_pairs") + __patt.Cc(("")))* s*
                ((__patt.P(("}")) )/( ("})")) + __patt.P(syntax_error(("expected '}'"))))
            )
        );
        __rule(self,"hash_pairs",
            __patt.V("hash_pair")* (s* __patt.P((","))* s* __patt.V("hash_pair"))^0* (s* __patt.P((",")))^-1
        );
        __rule(self,"hash_pair",
            (__patt.V("name") + __patt.P(("["))* s* __patt.V("expr")* s* (__patt.P(("]")) + __patt.P(syntax_error(("expected ']'")))))* s*
            __patt.P(("="))* s* __patt.V("expr")
        );
        __rule(self,"primary",
             __patt.V("ident")
            + __patt.V("range")
            + __patt.V("number")
            + __patt.V("string")
            + __patt.V("vnil")
            + __patt.V("vtrue")
            + __patt.V("vfalse")
            + __patt.V("stack")
            + __patt.V("array")
            + __patt.V("hash")
            + __patt.V("func")
            + __patt.V("short_func")
            + __patt.V("pattern")
            + __patt.P(("("))* s* __patt.V("expr")* s* (__patt.P((")")) + __patt.P( syntax_error(("expected ')'")) ))
        );
        __rule(self,"paren_expr",
            __patt.P(("("))* s* ( __patt.V("expr_list") + __patt.Cc(("")) )* s* (__patt.P((")")) + __patt.P( syntax_error(("expected ')'")) ))
        );
        __rule(self,"member_expr",
            __patt.Cs(
             __patt.P(("."))* s* __patt.V("name")
            + __patt.P(("["))* s* __patt.V("expr")* s* (__patt.P(("]")) + __patt.P( syntax_error(("expected ']'")) ))
            )
        );
        __rule(self,"method_expr",
            __patt.Cs(
             ((__patt.P(("."))  )/( (":")) + (__patt.P(("::")) )/( (".")))* s* __patt.V("name")* s* (__patt.V("short_expr") + __patt.V("paren_expr"))
            )
        );
        __rule(self,"access_expr",
            __patt.Cs(
             __patt.V("invoke_expr")* s* __patt.V("access_expr")
            + __patt.V("member_expr")
            )
        );
        __rule(self,"invoke_expr",
            __patt.Cs(
             (
                 __patt.V("method_expr")
                + __patt.V("member_expr")
                + __patt.V("short_expr")
                + __patt.V("paren_expr")
            )* s* __patt.V("invoke_expr")
            + __patt.V("method_expr")
            + __patt.V("short_expr")
            + __patt.V("paren_expr")
            )
        );
        __rule(self,"short_expr",
            ((__patt.P((":")) )/( ("(")))*
            ((s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")")) + __patt.Cc(Array(("_"))))* s* __patt.P(("{"))* __patt.Cs( __patt.V("func_body")* s )* (__patt.P(("}"))
            )/( make_short_func))* __patt.Cc((")"))
        );
        __rule(self,"suffix_expr",
             __patt.V("invoke_expr")
            + __patt.V("access_expr")
        );
        __rule(self,"term",
            __patt.Cs( __patt.V("primary")* (s* __patt.V("suffix_expr"))^0 )
        );
        __rule(self,"expr_list",
            __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
        );
        __rule(self,"expr",
            __patt.Cs( (__patt.V("infix_expr") + __patt.V("prefix_expr"))* (
                s* ((__patt.P(("?")) )/( (" and ")))* s* __patt.V("expr")* s* ((__patt.P((":")) )/( (" or ")))* s* __patt.V("expr")
            )^-1 )
        );

        --/*
        local binop_patt = __patt.P((
            __patt.P(("+")) + __patt.P(("-")) + __patt.P(("~")) + __patt.P(("^^")) + __patt.P(("*")) + __patt.P(("/")) + __patt.P(("%")) + __patt.P(("^")) + __patt.P((">>>")) + __patt.P((">>")) + __patt.P(("<<"))
            + __patt.P(("||")) + __patt.P(("&&")) + __patt.P(("|")) + __patt.P(("&")) + __patt.P(("==")) + __patt.P(("!=")) + __patt.P((">="))+ __patt.P(("<=")) + __patt.P(("<")) + __patt.P((">"))
            + (__patt.P(("as")) + __patt.P(("in")))* idsafe
        ));

        __rule(self,"infix_expr",
            (__patt.Ca( __patt.Cs( __patt.V("prefix_expr")* s )* (
                __patt.C( binop_patt )*
                __patt.Cs( s* __patt.V("prefix_expr")* (#(s* binop_patt)* s)^-1 )
            )^1 ) )/( fold_infix)
        );
        --*/

        --[=[
        // recursive descent is faster for stock Lua, but LJ2 is faster
        // with shift-reduce, so right now I'm biased towards LJ2 ;)
        rule infix_expr {
            {~ <bool_or_expr> ~}
        }
        function make_infix_expr(oper, term) {
            / (({~ term (&(s oper) s)? ~} {: {oper} {~ s term ~} :}*) ~> fold_infix) /
        }
        rule bool_or_expr {
            <{ make_infix_expr(/"||"/, /<bool_and_expr>/ }>
        }
        rule bool_and_expr {
            <{ make_infix_expr(/"&&"/, /<bit_or_expr>/ }>
        }
        rule bit_or_expr {
            <{ make_infix_expr(/"|"/,  /<bit_xor_expr>/ }>
        }
        rule bit_xor_expr {
            <{ make_infix_expr(/"^"/,  /<bit_and_expr>/ }>
        }
        rule bit_and_expr {
            <{ make_infix_expr(/"&"/,  /<equals_expr>/ }>
        }
        rule equals_expr {
            <{ make_infix_expr(/"=="|"!="/, /<cmp_expr>/ }>
        }
        rule cmp_expr {
            <{ make_infix_expr(/"<="|">="|"<"|">"/, /<shift_expr>/ }>
        }
        rule shift_expr {
            <{ make_infix_expr(/">>>"|">>"|"<<"|("as"|"in") idsafe/, /<add_expr>/ }>
        }
        rule add_expr {
            <{ make_infix_expr(/"+"|"-"|"~"/, /<mul_expr>/ }>
        }
        rule mul_expr {
            <{ make_infix_expr(/"*"|"/"|"%"/, /<pow_expr>/ }>
        }
        rule pow_expr {
            <{ make_infix_expr(/"^^"/, /<prefix_expr>/ }>
        }
        //]=]

        __rule(self,"prefix_expr",
            (__patt.Cg( __patt.C(
                 __patt.P(("@")) + __patt.P(("!")) + __patt.P(("#")) + __patt.P(("-")) + __patt.P(("~"))
                + (__patt.P(("throw")) + __patt.P(("typeof")))* idsafe
            )* s* __patt.V("prefix_expr"),nil) )/( fold_prefix)
            + __patt.Cs( s* __patt.V("term") )
        );

        -- binding expression rules
        __rule(self,"bind_stmt",
            __patt.Cs( ((__patt.V("bind_expr") + __patt.V("bind_binop_expr")) )/( ("%1;"))* semicol )
        );
        __rule(self,"bind_expr",
            __patt.Cs( __patt.V("bind_list")* s* __patt.P(("="))* s* (
                 __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0
                + __patt.P(syntax_error(("bad right hand <expr>")))
            ) )
        );
        __rule(self,"bind_binop",
            __patt.C( __patt.P(("+")) + __patt.P(("-")) + __patt.P(("*")) + __patt.P(("/")) + __patt.P(("%")) + __patt.P(("||")) + __patt.P(("|"))+ __patt.P(("&&"))
            + __patt.P(("&")) + __patt.P(("^^")) + __patt.P(("^")) + __patt.P(("~")) + __patt.P((">>>")) + __patt.P((">>")) + __patt.P(("<<"))
            )* __patt.P(("="))
        );
        __rule(self,"bind_binop_expr",
            __patt.Cs( __patt.V("bind_term")* s* __patt.V("bind_binop")* s* (__patt.V("expr") )/( make_binop_bind) )
        );
        __rule(self,"bind_list",
            __patt.V("bind_term")* (s* __patt.P((","))* s* __patt.V("bind_term"))^0
        );
        __rule(self,"bind_term",
            __patt.Cs(
             __patt.V("primary")* (s* __patt.V("bind_member"))^1
            + __patt.Cs( __patt.V("name")* (__patt.Carg(1) )/( lookup_or_define) )
            )
        );
        __rule(self,"bind_member",
            __patt.Cs(
             __patt.V("suffix_expr")* s* __patt.V("bind_member")
            + __patt.V("bind_suffix")
            )
        );
        __rule(self,"bind_suffix",
            __patt.Cs(
             __patt.P(("."))* s* __patt.V("name")* s
            + __patt.P(("["))* s* __patt.V("expr")*  s* __patt.P(("]"))
            )
        );

        -- PEG grammar and pattern rules
        __rule(self,"pattern",
            __patt.P(("/"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("/")) )/( ("__patt.P(%1)"))
        );
        __rule(self,"grammar_decl",
            __patt.Cs( ((
                __patt.P(("grammar"))* idsafe* s* __patt.Cs( __patt.V("name")* __patt.Carg(1)* (__patt.Cc(("__env")) )/( define) )* s*
                __patt.P(("{"))* __patt.Cs( __patt.V("grammar_body")* s )* __patt.P(("}"))
            ) )/( ("self.%1=__grammar(__env,\"%1\",function(__env,self) %2 end);")) )
        );
        __rule(self,"grammar_body",
            __patt.Cg( __patt.Cc(("lexical")),"scope")*
            (s* __patt.V("grammar_body_stmt"))^0
        );
        __rule(self,"grammar_body_stmt",
             __patt.V("rule_decl")
            + __patt.V("var_decl")
            + __patt.V("func_decl")
            + #__patt.V("return_stmt")* __patt.P(syntax_error(("return outside of function body")))
            + __patt.V("statement")
        );
        __rule(self,"rule_decl",
            __patt.P(("rule"))* idsafe* s* __patt.V("name")* s* __patt.P(("{"))* __patt.Cs( s* __patt.V("rule_body")* s )* (__patt.P(("}"))
            )/( ("__rule(self,\"%1\",%2);"))
        );
        __rule(self,"rule_body",
            __patt.V("rule_alt") + __patt.Cc(("__patt.P(nil)"))
        );
        __rule(self,"rule_alt",
            __patt.Cs( ((__patt.P(("|")) )/( (""))* s)^-1* __patt.V("rule_seq")* (s* ((__patt.P(("|")) )/( ("+")))* s* __patt.V("rule_seq"))^0 )
        );
        __rule(self,"rule_seq",
            (__patt.Ca( __patt.Cs( s* __patt.V("rule_suffix") )^1 ) )/( function(a)  do return a:concat(("*")) end  end)
        );
        __rule(self,"rule_rep",
            __patt.Cs( (__patt.P(("+")) )/( ("^1")) + (__patt.P(("*")) )/( ("^0")) + (__patt.P(("?")) )/( ("^-1")) + __patt.P(("^"))*s*(__patt.P(("+"))+__patt.P(("-")))^-1*s*((__patt.R("09")))^1 )
        );
        __rule(self,"rule_prefix",
            __patt.Cs( (((__patt.P(("&")) )/( ("#"))) + ((__patt.P(("!")) )/( ("-"))))* (__patt.Cs( s* __patt.V("rule_prefix") ) )/( ("%1%2"))
            + __patt.V("rule_primary")
            )
        );

        local prod_oper = __patt.P( __patt.P(("->")) + __patt.P(("~>")) + __patt.P(("=>")) );

        __rule(self,"rule_suffix",
            __patt.Cf((__patt.Cs( __patt.V("rule_prefix")* (#(s* prod_oper)* s)^-1 )*
            __patt.Cg( __patt.C(prod_oper)* __patt.Cs( s* __patt.V("rule_prod") ),nil)^0) , function(a,o,b,t) 
                if (o )==( ("=>")) then  
                     do return ("__patt.Cmt(%s,%s)"):format(a,b) end
                
                 elseif (o )==( ("~>")) then  
                     do return ("__patt.Cf(%s,%s)"):format(a,b) end
                
                else 
                    if (t )==( ("array")) then  
                         do return ("__patt.Ca(%s,%s)"):format(a,b) end
                    
                     elseif (t )==( ("hash")) then  
                         do return ("__patt.Ch(%s,%s)"):format(a,b) end
                    
                    else 
                         do return ("(%s)/(%s)"):format(a,b) end
                     end 
                 end 
             end)
        );
        __rule(self,"rule_prod",
            __patt.Cs(
             __patt.V("array")* __patt.Cc(("array"))
            + __patt.V("hash")*  __patt.Cc(("hash"))
            + __patt.V("term")
            )
        );
        __rule(self,"rule_primary",
            ( __patt.V("rule_group")
            + __patt.V("rule_term")
            + __patt.V("rule_class")
            + __patt.V("rule_predef")
            + __patt.V("rule_back_capt")
            + __patt.V("rule_group_capt")
            + __patt.V("rule_sub_capt")
            + __patt.V("rule_const_capt")
            + __patt.V("rule_hash_capt")
            + __patt.V("rule_array_capt")
            + __patt.V("rule_simple_capt")
            + __patt.V("rule_any")
            + __patt.V("rule_ref")
            )* (s* __patt.V("rule_rep"))^0
        );
        __rule(self,"rule_group",
            __patt.Cs( __patt.P(("("))* s* (__patt.V("rule_alt") + __patt.P( syntax_error(("expected <rule_alt>")) ))* s*
                (__patt.P((")")) + __patt.P( syntax_error(("expected ')'")) ))
            )
        );
        __rule(self,"rule_term",
            __patt.Cs( (__patt.V("string") )/( ("__patt.P(%1)")) )
        );
        __rule(self,"rule_class",
            __patt.Cs(
                ((__patt.P(("[")) )/( ("(")))* ((__patt.P(("^")) )/( ("__patt.P(1)-")))^-1*
                ((__patt.Ca( (-__patt.P(("]"))* __patt.V("rule_item"))^1 ) )/( function(a)  do return ((("("))..(a:concat(("+"))))..((")")) end  end))*
                ((__patt.P(("]")) )/( (")")))
            )
        );
        __rule(self,"rule_item",
            __patt.Cs( __patt.V("rule_predef") + __patt.V("rule_range")
            + (__patt.C(__patt.P(1)) )/( function(c)  do return ("__patt.P(%q)"):format(c) end  end)
            )
        );
        __rule(self,"rule_predef",
            __patt.Cs( ((__patt.P(("%")) )/( ("")))* (
                 (__patt.C( ((__patt.R("09")))^1 ) )/( ("__patt.Carg(%1)"))
                + (__patt.V("name") )/( ("__patt.Def(\"%1\")"))
            ) )
        );
        __rule(self,"rule_range",
            (__patt.Cs( __patt.P(1)* ((__patt.P(("-")))/(("")))* -__patt.P(("]"))* __patt.P(1) ) )/( function(r)  do return ("__patt.R(%q)"):format(r) end  end)
        );
        __rule(self,"rule_any",
            __patt.Cs( (__patt.P((".")) )/( ("__patt.P(1)")) )
        );
        __rule(self,"rule_ref",
            __patt.Cs(
            ((__patt.P(("<")) )/( ("")))* s*
                ( (__patt.V("name") )/( ("__patt.V(\"%1\")"))
                + __patt.Cs( ((__patt.P(("{")) )/( ("__patt.P(")))* s* __patt.V("expr")* s* ((__patt.P(("}")) )/( (")"))) )
                )* s*
            ((__patt.P((">")) )/( ("")))
            + __patt.V("qname")
            )
        );
        __rule(self,"rule_group_capt",
            __patt.Cs( __patt.P(("{:"))* (((__patt.V("name") )/( quote)* __patt.P((":"))) + __patt.Cc(("nil")))* __patt.Cs( s* __patt.V("rule_alt") )* s* (__patt.P((":}"))
            )/( ("__patt.Cg(%2,%1)"))
            )
        );
        __rule(self,"rule_back_capt",
            __patt.P(("="))* (((__patt.V("name") )/( quote)) )/( ("__patt.Cb(%1)"))
        );
        __rule(self,"rule_sub_capt",
            __patt.P(("{~"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("~}")) )/( ("__patt.Cs(%1)"))
        );
        __rule(self,"rule_const_capt",
            __patt.P(("{`"))* __patt.Cs( s* __patt.V("expr")* s )* (__patt.P(("`}")) )/( ("__patt.Cc(%1)"))
        );
        __rule(self,"rule_hash_capt",
            __patt.P(("{%"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("%}")) )/( ("__patt.Ch(%1)"))
        );
        __rule(self,"rule_array_capt",
            __patt.P(("{@"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("@}")) )/( ("__patt.Ca(%1)"))
        );
        __rule(self,"rule_simple_capt",
            __patt.P(("{"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("}")) )/( ("__patt.C(%1)"))
        );
     end);
    __method(self,"compile",function(self,lupa, name) 
        local ctx = __env.Lupa.Context:new();
        ctx:enter();
        ctx:define(("_G"));
        ctx:define(("self"));
        local lua = __env.Lupa.Grammar:match(lupa, 1, ctx);
        ctx:leave();
         do return lua end
     end);
 end);

_G.eval = function(src) 
    local eval = __env.assert(__env.loadstring(__env.Lupa:compile(src),(("=eval:"))..(src)));
     do return eval() end
 end;

local getopt = function(...) local args=Array(...);
   local opt = Hash({ });
   local idx = 0;
   local len = #(args);
   while (idx )<( len)  do local __break repeat 
      idx = (idx )+( 1);
      local arg = args[idx];
      if (arg:sub(1,1) )==( ("-")) then  
         local o = arg:sub(2);
         if (o )==( ("o")) then  
            idx = (idx )+( 1);
            opt[("o")] = args[idx];
         
          elseif (o )==( ("l")) then  
            opt[("l")] = (true);
         
          elseif (o )==( ("b")) then  
            idx = (idx )+( 1);
            opt[("b")] = args[idx];
         
         else 
            __env.error((("unknown option: "))..(arg), 2);
          end 
      
      else 
         opt[("file")] = arg;
       end 
    until true if __break then break end end 
    do return opt end
 end;

local run = function(...) 
   local opt = getopt(...);
   local sfh = __env.assert(__env.io.open(opt[("file")]));
   local src = sfh:read(("*a"));
   sfh:close();

   local lua = __env.Lupa:compile(src);
   if opt[("l")] then  
      __env.io.stdout:write(lua);
      __env.os.exit(0);
    end 

   if opt[("o")] then  
      local outc = __env.io.open(opt[("o")], ("w+"));
      outc:write(lua);
      outc:close();
   
   else 
      lua = lua:gsub(("^%s*#![^\n]*"),(""));
      local main = __env.assert(__env.loadstring(lua,(("="))..(opt[("file")])));
      if opt[("b")] then  
         local outc = __env.io.open(opt.b, ("wb+"));
         outc:write(__env.String.dump(main));
         outc:close();
      
      else 
         local main_env = setmetatable(Hash({ }), Hash({ __index = _G }));
         __env.setfenv(main, main_env);
         main(opt[("file")], ...);
       end 
    end 
 end;

arg = arg  and  Array( __env.unpack(arg) )  or  Array( );
do 
   -- from strict.lua
   local mt = getmetatable(_G);
   if (mt )==( (nil)) then  
      mt = __env.newtable();
      setmetatable(_G, mt);
    end 

   mt.__declared = __env.newtable();

   local function what() 
      local d = __env.debug.getinfo(3, ("S"));
       do return ((d )and( d.what ))or( ("C")) end
    end

   --[=[
   mt.__newindex = function(t, n, v) {
      if !mt.__declared[n] {
         var w = what()
         if w != "main" && w != "C" {
            error("assign to undeclared variable '${n}'", 2)
         }
         mt.__declared[n] = true
      }
      rawset(t, n, v)
   }
   ]=]
   mt.__index = function(t, n) 
      if (not(mt.__declared[n]) )and(( what() )~=( ("C"))) then  
         __env.error(("variable '"..tostring(n).."' is not declared"), 2);
       end 
       do return rawget(t, n) end
    end;
 end

__env.Lupa.PATH = ("./?.lu;./lib/?.lu;./src/?.lu");
do 
   local P = _G[("package")];
   P.loaders[(#(P.loaders) )+( 1)] = function(modname) 
      local filename = modname:gsub(("%."), ("/"));
      for path in __op_each(__env.Lupa.PATH:gmatch(("([^;]+)")))  do local __break repeat 
         if (path )~=( ("")) then  
            local filepath = path:gsub(("?"), filename);
            local file = __env.io.open(filepath, ("r"));
            if file then  
               local src = file:read(("*a"));
               local lua = __env.Lupa:compile(src);
               local mod = __env.assert(__env.loadstring(lua, (("="))..(filepath)))();
               P.loaded[modname] = mod;
                do return mod end
             end 
          end 
       until true if __break then break end end 
    end;
 end

if arg[1] then   run(__env.unpack(arg));  end 
-- vim: ft=lupa

