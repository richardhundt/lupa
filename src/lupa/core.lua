local __env = setmetatable({ }, { __index = _G })
package.loaded['lupa.core'] = __env
setfenv(1, __env)
for k,v in pairs(_G) do __env[k] = v end

local bit = require("bit")
local ffi = require('ffi')

package.path  = ';;./lib/?.lua;'..package.path
package.cpath = ';;./lib/?.so;'..package.cpath

__env.__type = { }
__env.__type.__proto = { }

do
   local paths = {
      ".",
      "./lib",
      "./src",
      os.getenv('HOME').."/.lupa",
      "/usr/local/lib/lupa",
      "/usr/lib/lupa",
   }
   local buf = { }
   for i, frag in ipairs(paths) do
      buf[#buf + 1] = frag.."/?.lu"
      buf[#buf + 1] = frag.."/?/init.lu"
   end
   LUPA_PATH = table.concat(buf, ';')..';'
end
table.insert(package.loaders, function(modname)
   local filename = modname:gsub("%.", "/")
   for path in LUPA_PATH:gmatch("([^;]+)") do
      if path ~= "" then
         local lang = package.loaded["lupa.lang"]
         if not lang then return end
         local Compiler = lang.Compiler
         local filepath = path:gsub("?", filename)
         local file = io.open(filepath, "r")
         if file then
            local src = file:read("*a")
            return function(...)
               local ok, rv = pcall(function(...)
                  local lua  = Compiler:compile(src)
                  local main = assert(loadstring(lua, '='..filepath))
                  return main(...)
               end, ...)
               if not ok then
                  throw("failed to load "..modname..": "..tostring(rv), 2)
               end
               return rv
            end
         end
      end
   end
end)

function newtable(...) return { ... } end
local rawget, rawset = rawget, rawset
rawtype = _G.type
rawlen = function(tab) return #tab end

function typeof(this)
   local t = rawtype(this)
   if t == 'cdata' then
      return ffi.typeof(this)
   elseif t == 'table' then 
      return this.__type
   elseif t == 'number' then
      return Number
   elseif t == 'string' then
      return String
   elseif t == 'function' then
      return Function
   elseif t == 'thread' then
      return Thread
   elseif t == 'nil' then
      return Nil
   elseif t == 'boolean' then
      return Boolean
   elseif t == 'userdata' then
      if _patt.type(this) == 'pattern' then
         return Pattern
      else
         return getmetatable(this)
      end
   else
      return getmetatable(this)
   end
end

throw = error

function case(this, that)
   if this == that then
      return true
   elseif typeof(this).__match then
      return this:__match(that)
   else
      local meta = typeof(that)
      if meta == Type or meta == Class or meta == Trait then
         return __is__(this,that)
      end
   end
   return false
end

local Meta = {
   __tostring = function(a) return a:toString() end;
   __call = function(a, ...) return a:apply(...) end;
}

local MetaTrait = {
   '__add',
   '__sub',
   '__mul',
   '__div',
   '__mod',
   '__pow',
   '__unm',
   '__len',
   '__eq',
   '__ne',
   '__gt',
   '__lt',
   '__le',
   '__ge',
   '__tostring',
   '__pairs',
   '__ipairs',
   '__each',
   '__lshift',
   '__rshift',
   '__arshift',
   '__bor',
   '__bxor',
   '__bnot',
   '__band',
   '__call',
   '__match',
   '__concat',
}

function environ(outer)
   if not outer then outer = __env end
   return setmetatable({ }, { __index = outer })
end

local function lookup(proto)
   return function(self, key)
      local val = proto[key]
      if val == nil then
         throw(TypeError:new("no such member '"..tostring(key).."' via "..tostring(typeof(self)), 2))
      end
      return val
   end
end

function class(outer, name, from, with, body)
   if from == nil then
      from = Any
   else
      if  typeof(from) ~= from  -- object
      and typeof(from) ~= Class
      and typeof(from) ~= Type then
         throw("TypeError: cannot extend "..tostring(from), 2)
      end
   end

   local class = { }
   local proto = { }
   local rules = { }

   proto.__type = class
   class.__name = name
   class.__from = from
   class.__size = from.__size
   class.__with = { }
   class.__need = { }
   class.__body = body

   class.__proto = setmetatable(proto, { __index = from.__proto })
   proto.__index = lookup(proto)
   for i=1, #MetaTrait do
      local sym = MetaTrait[i]
      if from.__proto[sym] ~= nil then
         class.__proto[sym] = from.__proto[sym]
      end
   end

   local inner = { }
   setmetatable(inner, { __index = outer })
   class.__inner = setmetatable({ }, {
      __index = inner;
      __newindex = function(env, key, val)
         inner[key] = val
         class[key] = val
      end;
   })
   class.__inner[name] = class

   class.__rules = { }
   for k,v in pairs(from.__rules) do
      class.__rules[k] = v
   end

   for k,v in pairs(Meta) do
      class.__proto[k] = v
   end
   setmetatable(class, Class.__proto)

   if with then
      for i=1,#with do
         if typeof(with[i]) ~= Trait then
            throw(TypeError:new(tostring(with[i]).." is not a trait"), 2)
         end
         with[i]:make(class.__inner, class)
      end
   end

   local super = setmetatable({ }, from.__proto)
   body(class.__inner, class, super)

   local __extend__ = rawget(from, '__extend__')
   if __extend__ then
      __extend__(from, class)
   end

   for k,v in pairs(class.__need) do
      if v == true then
         if rawget(class, k) == nil then
            throw(ComposeError:new("static '"..tostring(k).."' is needed in "..name), 2)
         end
      else
         if class.__proto[k] == nil then
            throw(ComposeError:new("'"..tostring(k).."' is needed in "..name), 2)
         end
      end
   end

   local __finalize__ = rawget(class, '__finalize__')
   if __finalize__ then
      __finalize__(class)
   end

   return class
end

function trait(into, name, with, want, body)
   local trait = { }
   trait.__name = name
   trait.__with = with
   trait.__want = want
   trait.__body = body
   setmetatable(trait, Trait.__proto)
   return trait
end
function needs(into, name, meta)
   into.__need[name] = meta
end
function with(into, with)
   for i=1,#with do
      with[i]:make(into.__inner, into)
   end
   return into
end
function object(into, name, from, with, body)
   local inst = class(into, name, from, with, body)
   inst.new = nil
   inst.__proto.toString = function(self)
      return ('%s<object %s>: %p'):format(type(self), tostring(name), self)
   end
   inst.__proto.members = function(self)
      return self.__proto
   end
   setmetatable(inst, inst.__proto)
   if inst.__proto.init then
      inst.__proto.init(inst)
   end
   return inst
end

function has(into, name, type, ctor, meta) 
   local idx
   if meta then
      into[#into + 1] = name
      idx = #into
   else
      into.__size = into.__size + 1
      idx = into.__size
   end

   local get, set
   if type then
      function set(obj, val)
         rawset(obj, idx, type:coerce(val))
      end
   else
      function set(obj, val)
         rawset(obj, idx, val)
      end
   end
   function get(obj)
      local val = rawget(obj, idx)
      if val == nil then
         val = ctor(obj)
         set(obj, val)
      end
      return val
   end

   if meta then
      into[name] = get
      into['__set_'..name] = set
   else
      into.__proto[name] = get
      into.__proto['__set_'..name] = set
   end
end

function method(into, name, code, meta)
   if meta then
      into[name] = code
   else
      into.__proto[name] = code
   end
end

function rule(into, name, patt) 
   local key = '_'..name
   local get = function(obj, ...)
      local rule = rawget(obj, key)
      if rule == nil then
         local grmr = { }
         for k,v in pairs(into.__rules) do
            if _patt.type(v) == "pattern" then
               grmr[k] = v
            end
         end
         grmr[1] = name
         rule = _patt.P(grmr)
         rawset(obj, key, rule)
      end
      if select('#', ...) > 0 then
         return rule:match(...)
      end
      return rule
   end

   into.__proto[name] = get
   into.__rules[name] = patt
end

function try(try,...)
   local ok, er = pcall(try)
   if not ok then
      for i=1, select("#",...) do
         local node = select(i,...)
         local body = node.body
         local type = node.type
         if type == nil then
            return body(er)
         end
         if __match__(er, type) then
            return body(er)
         end
      end
      throw(er, 2)
   end
end

_patt = require("lpeg")
_patt.setmaxstack(1024)
do
   local function make_capt_hash(init)
       return function(tab)
         if init ~= nil then
            for k,v in __each__(init) do
               if tab[k] == nil then
                  tab[k] = v
               end
            end
         end
         return setmetatable(tab, Table.__proto)
      end
   end
   local function make_capt_array(init)
       return function(tab)
         if init ~= nil then
            for i=1, #init do
               if tab[i] == nil then
                  tab[i] = init[i]
               end
            end
         end 
         return setmetatable(tab, Array.__proto)
      end
   end

   _patt.Ch = function(patt,init)
       return Pattern.__proto.__div(_patt.Ct(patt), make_capt_hash(init))
   end
   _patt.Ca = function(patt,init)
       return Pattern.__proto.__div(_patt.Ct(patt), make_capt_array(init))
   end

   local def = { }

   def.nl  = _patt.P("\n")
   def.pos = _patt.Cp()

   local any=_patt.P(1)
   _patt.locale(def)

   def.a = def.alpha
   def.c = def.cntrl
   def.d = def.digit
   def.g = def.graph
   def.l = def.lower
   def.p = def.punct
   def.s = def.space
   def.u = def.upper
   def.w = def.alnum
   def.x = def.xdigit
   def.A = any - def.a
   def.C = any - def.c
   def.D = any - def.d
   def.G = any - def.g
   def.L = any - def.l
   def.P = any - def.p
   def.S = any - def.s
   def.U = any - def.u
   def.W = any - def.w
   def.X = any - def.x

   _patt.def = def
   _patt.Def = function(id)
      if def[id] == nil then
         throw("No predefined pattern '"..tostring(id).."'", 2)
      end
      return def[id]
   end
end

function import(into, from, what, dest) 
   local mod = __load__(from)
   if mod == true then
      throw(ImportError:new("'"..tostring(from).."' does not export any symbols."), 2)
   end
   if dest then
      if #what == 0 then
         into[dest] = setmetatable({ }, { __index = lookup(mod) })
      else
         into[dest] = setmetatable({ }, { __index = lookup({ }) })
      end
      into = into[dest]
   end 
   for i=1, #what do
      local key = what[i]
      local val = rawget(mod, key)
      if val == nil then
         throw(ImportError:new("'"..tostring(key).."' from '"..tostring(from).."' is nil"), 2)
      end
      into[key] = val
   end
   return mod
end

function export(from, ...)
   local what = Array:new(...)
   local exporter = setmetatable({ }, { __index = lookup({ }) })
   for i = 1, #what do
      local expt = what[i];
      local key, val = expt[1], expt[2]
      if val == nil then
         throw(ExportError:new(tostring(key).."' is nil"), 2)
      end
      exporter[key] = val
   end
   return exporter
end

function __load__(from)
   local path = from
   if rawtype(from) == "table" then
      path = table.concat(from, ".")
   end
   local mod = require(path)
   if mod == true then
      mod = _G
      if rawtype(from) == 'string' then
         local orig = from
         from = { }
         for frag in orig:gmatch('([^%.]+)') do
            from[#from + 1] = frag
         end
      end
      for i = 1, #from do -- FIXME: hack!
         mod = rawget(mod or { }, from[i])
      end
   end
   return mod
end

function __spread__(this)
   local mt = typeof(this)
   local __spread = mt and rawget(mt, '__spread')
   if __spread then
      return __spread(this)
   end
   return unpack(this)
end

function __each__(a, ...)
   if rawtype(a) == "function" then
      return a, ...
   end
   local mt = typeof(a)
   local __each = mt and mt.__proto.__each
   if __each then
      return __each(a)
   end
   return pairs(a)
end
function __is__(this, that)
   if type(this) == 'cdata' then
      return ffi.istype(this, that)
   end
   return this:is(that)
end
function __does__(this, that)
   return this:does(that)
end
function __can__(this, that)
   return this:can(that)
end
function __match__(this, that)
   local mt = typeof(this)
   local __match = mt and mt.__proto.__match
   if __match then return __match(this, that) end
   return this == that
end

function __bnot__(this)
   local mt = typeof(this)
   local __bnot = mt and mt.__proto.__bnot
   if __bnot then return __bnot(this) end
   return bit.bnot(tonumber(this))
end

function __bor__(this, that)
   local mt = typeof(this)
   local __bor = mt and mt.__proto.__bor
   if __bor then return __bor(this, that) end
   return bit.bor(tonumber(this), tonumber(that))
end
function __band__(this, that)
   local mt = typeof(this)
   local __band = mt and mt.__proto.__band
   if __band then return __band(this, that) end
   return bit.band(tonumber(this), tonumber(that))
end
function __bxor__(this, that)
   local mt = typeof(this)
   local __bxor = mt and mt.__proto.__bxor
   if __bxor then return __bxor(this, that) end
   return bit.bxor(tonumber(this), tonumber(that))
end
function __lshift__(this, that)
   local mt = typeof(this)
   local __lshift = mt and mt.__proto.__lshift
   if __lshift then return __lshift(this, that) end
   return bit.lshift(tonumber(this), tonumber(that))
end
function __rshift__(this, that)
   local mt = typeof(this)
   local __rshift = mt and mt.__proto.__rshift
   if __rshift then return __rshift(this, that) end
   return bit.rshift(tonumber(this), tonumber(that))
end
function __arshift__(this, that)
   local mt = typeof(this)
   local __arshift = mt and mt.__proto.__arshift
   if __arshift then return __arshift(this, that) end
   return bit.arshift(tonumber(this), tonumber(that))
end

Any = setmetatable({ }, Meta)
Any.coerce = function(self, ...) return ...  end
Any.check  = function(self, ...) return true end
Any.toString = function() return "<type Any>" end
Any.is = function(self, that)
   return that:check(self)
end
Any.__name = "Any"
Any.__from = { }
Any.__with = { }
Any.__size = 0
Any.__rules = { }
Any.__proto = { }
Any.__proto.__type = Any
Any.__proto.__index = lookup(Any.__proto)
Any.__proto.__match = function(a, b)
   if typeof(b) == Class or typeof(b) == Trait or typeof(b) == Type then
      return b:check(a)
   end
   return a == b
end
Any.__proto.apply = function(self)
   error(tostring(self).." is not callable", 2)
end
Any.__proto.toString = function(self)
   return ('%s%s: %p'):format(type(self), tostring(typeof(self)), self)
end
Any.__proto.is = function(self, that)
   return that:check(self)
end
Any.__proto.can = function(self, key)
   return typeof(self).__proto[key] ~= nil
end
Any.__proto.does = function(self, that)
   return typeof(self).__with[that.__body] ~= nil
end

Type = setmetatable({ }, Meta)
Type.__name  = "Type"
Type.new = function(meta, name)
   local type = { }
   local proto = { }
   type.__name = name
   type.__from = Any
   type.__need = { }
   type.__with = { }
   type.__body = function() end
   type.__size = 0
   type.__rules = { }
   type.__proto = setmetatable({ }, { __index = Any.__proto })
   type.__proto.__type  = type
   type.__proto.__index = lookup(type.__proto)
   type.toString = function() return '<type '..name..'>' end

   for k,v in pairs(Meta) do
      type.__proto[k] = v
   end
   return setmetatable(type, Type.__proto)
end
Type.toString = function() return '<type Type>' end
Type.__proto = setmetatable({ }, { __index = Any.__proto })
Type.__proto.__type = Type
Type.__proto.__index = lookup(Type.__proto)
Type.__proto.check = function(self, that)
   local type = typeof(that)
   if type == Type then
      type = that
   end
   while type do
      if type == self then
         return true
      end
      type = type.__from
   end
   return false
end
Type.__proto.coerce = function(self, ...)
   if not self:check(...) then
      throw(TypeError:new("cannot coerce "..tostring(...).." to "..tostring(self), 2))
   end
   return ...
end
Type.__match = function(self, that)
   return self:check(that)
end
Type.__maybe = function(self, that)
   local this = self
   local maybe = Type:new('?'..tostring(self.__name))
   maybe.coerce = function(self, ...)
      if ... == nil then return ... end
      return this:coerce(...)
   end
   maybe.check = function(self, ...)
      if ... == nil then return true end
      return this:check(...)
   end
   return maybe
end
Type.__bor = function(this, that)
   local union = Type:new(this.__name..'|'..that.__name)
   union.coerce = function(self, ...)
      if this:check(...) then
         return this:coerce(...)
      elseif that:check(...) then
         return that:coerce(...)
      end
      throw(TypeError:new("cannot coerce "..tostring(typeof(...)).." to "..tostring(self), 2))
   end
   return union
end
for k,v in pairs(Meta) do Type.__proto[k] = v end

local function newtype(name)
   return Type:new(name)
end

Enum = newtype"Enum"
Enum.new = function(class, name, proto)
   local enum = { __name = name }
   local nval = -1
   for i,spec in ipairs(proto) do
      local n, v = spec[1], spec[2]
      if v then
         nval = v
      else
         nval = nval + 1
         v = nval
      end
      enum[n] = function() return v end
      enum[v] = n
   end
   return setmetatable(enum, class)
end
Enum.__proto = setmetatable({ }, { __index = Type.__proto })
Enum.__proto.__type = Enum
Enum.__proto.__index = lookup(Enum.__proto)
Enum.__proto.coerce = function(self, that)
   if not self:check(that) then
      throw(TypeError:new(tostring(that).." is not a member of "..tostring(self), 2), 2)
   end
   return that
end
Enum.__proto.check = function(self, that)
   return rawget(self,that) ~= nil
end

function enum(name, proto)
   return Enum:new(name, proto)
end

function guard(name, body)
   local guard = Type:new(name)
   guard.coerce = function(self, ...)
      return body(self, ...)
   end
   guard.check = function(self, ...)
      return (pcall(body, self, ...))
   end
   return guard
end

Class = newtype"Class"
Class.__proto = setmetatable({ }, { __index = Type.__proto })
Class.__proto.__type = Class
Class.__proto.__index = lookup(Class.__proto)
Class.__proto.toString = function(self)
   return "<class "..tostring(self.__name)..">"
end
Class.__proto.new = function(self, ...)
   local obj = setmetatable({ }, self.__proto)
   if self.__proto.init then
      self.__proto.init(obj, ...)
   end
   return obj
end
Class.__proto.members = function(self)
   return self.__proto
end
for k,v in pairs(Meta) do
   Class.__proto[k] = v
end

Trait = newtype"Trait"
Trait.__proto = setmetatable({ }, { __index = Type.__proto })
Trait.__proto.__type = Trait
Trait.__proto.__index = lookup(Trait.__proto)
Trait.__proto.toString = function(self)
   return "<trait "..tostring(self.__name)..">"
end
Trait.__proto.check = function(self, that)
   return that.__with[self.__body] ~= nil
end
Trait.__proto.coerce = function(self, that)
   if not self:check(that) then
      throw(TypeError:new(tostring(that).." does not compose: "..tostring(self), 2))
   end
   return that
end
Trait.__proto.__getitem = function(self, ...)
   local args = { ... }
   local want = self.__want - #args
   if want ~= 0 then
      throw(TypeError:new(
         "trait "..tostring(self.__name)..
         " takes "..tostring(self.__want)..
         " parameters but got "..tostring(#args)
      ), 2)
   end
   local copy = trait(nil, self.__name, self.__with, want, self.__body)
   local make = self.make
   copy.make = function(self, into, recv)
      return make(self, into, recv, unpack(args))
   end
   return copy
end
Trait.__proto.make = function(self, into, recv, ...)
   if self.__want ~= 0 then
      throw(TypeError:new(
         "trait "..tostring(self.__name)..
         " takes "..tostring(self.__want).." parameters"
      ), 2)
   end
   for i = 1, #self.__with, 1 do
      self.__with[i]:make(into, recv)
   end
   self.__body(into, recv, ...)
   recv.__with[self.__body] = self
   return into
end

Array = newtype"Array"
Array.new = function(self, ...)
   return setmetatable({ ... }, self.__proto)
end
Array.apply = function(self, ...)
   return setmetatable({ ... }, self.__proto)
end
Array.__getitem = function(self, type)
   return guard('Array['..tostring(type.__name)..']', function(self, samp)
      for i=1, #samp do
         samp[i] = type:coerce(samp[i])
      end
      return samp
   end)
end
Array.__proto.__type = Array
Array.__proto.__index = Array.__proto
Array.__proto.len = function(self)
   return #self
end
Array.__proto.apply = function(self, ...)
   local recv = self[1]
   local args = { unpack(self, 2) }
   for i=1, select('#', ...) do
      args[#args + 1] = select(i, ...)
   end
   return self[1](unpack(args))
end
Array.__proto.toString = function(self)
   local buf = { }
   for i = 1, #self do
      if rawtype(self[i]) == "string" then
         buf[#buf + 1] = string.format("%q", self[i])
      else
         buf[#buf + 1] = tostring(self[i])
      end 
   end
   return "["..table.concat(buf, ",").."]"
end
Array.__proto.__each = ipairs
Array.__proto.__getitem = rawget
Array.__proto.__setitem = rawset
Array.__proto.__match = function(a, b)
   if not __is__(b,Array) then return false end
   if a:len() ~= b:len() then return false end
   for i=1, a:len() do
      local va, vb = a:__getitem(i), b:__getitem(i)
      if not va == vb then
         return false
      end
   end
   return true
end
Array.__proto.__add = function(a, b)
   local c = Array:new(unpack(a))
   for i=1, #b do c[#c + 1] = b[i] end
   return c
end
Array.__proto.unpack = unpack
Array.__proto.insert = table.insert
Array.__proto.remove = table.remove
Array.__proto.concat = table.concat
Array.__proto.sort = function(self, cond)
   table.sort(self, cond)
   return self
end
Array.__proto.each = function(self, block)
   for i=1, #self do
      block(self[i])
   end
   return self
end
Array.__proto.map = function(self, block)
   local out = Array:new()
   for i = 1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.__proto.inject = function(self, code)
   for i=1, #self do
      self[i] = code(self[i])
   end
   return self
end
Array.__proto.grep = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v=self[i]
      if block(v) then
         out[#out + 1] = v
      end
   end
   return out
end
Array.__proto.push = function(self, v)
   self[#self + 1] = v
end
Array.__proto.pop = function(self)
   return table.remove(self)
end
Array.__proto.shift = function(self)
   return table.remove(self, 1)
end
Array.__proto.unshift = function(self, v)
   table.insert(self, 1, v)
end
Array.__proto.splice = function(self, offset, count, ...)
   local args = Array:new(...)
   local out  = Array:new()
   for i=offset, offset + count - 1 do
      out:push(self:remove(offset))
   end
   for i=#args, 1, -1 do
      self:insert(offset, args[i]);
   end
   return out
end
Array.__proto.reverse = function(self) 
   local out = Array:new()
   for i=1, #self do
      out[i] = self[#self - i + 1]
   end
   return out
end

Table = newtype"Table"
Table.new = function(self, table)
   return setmetatable(table or { }, self.__proto)
end
Table.apply = function(self, ...)
   return self:new(...)
end
Table.MODE = { k = { }, v = { }, kv = { } } 
Table.__proto.__index = Table.__proto
Table.__proto.weak = function(self, mode)
   if mode == 'k' or mode == 'kv' or mode == 'v' then
      debug.setmetatable(self, Table.MODE[mode])
      return self
   end
   error("invalid weak mode '"..tostring(mode).."', must be 'k', 'kv' or 'v'", 2)
end
Table.__proto.next = next
Table.__proto.as = function(this, that)
   return setmetatable(this, that)
end
Table.__proto.toString = function(self)
   local buf = { }
   for k,v in pairs(self) do
      local _v
      if rawtype(v) == "string" then
         _v = string.format("%q", v)
      else
         _v = tostring(v)
      end
      if rawtype(k) == "string" then
         buf[#buf + 1] = k.."=".._v
      else
         buf[#buf + 1] = "["..tostring(k).."]="..tostring(_v)
      end
   end
   return "{"..table.concat(buf, ",").."}"
end
Table.__proto.__each = pairs
Table.__proto.len = function(self) return #self end
Table.__proto.each = function(self)
   return pairs(self)
end
Table.__proto.__getitem = rawget
Table.__proto.__setitem = rawset

for k,v in pairs(table) do Table.__proto[k] = v end
for m,t in pairs(Table.MODE) do
   t.__mode = m
   t.__from = Table
   for k,v in pairs(Table) do
      t[k] = v
   end
end

Range = newtype"Range"
Range.new = function(self, min, max, inc) 
   min = assert(tonumber(min), "range min is not a number")
   max = assert(tonumber(max), "range max is not a number")
   inc = assert(tonumber(inc or 1), "range inc is not a number")
   return setmetatable({ min, max, inc }, self.__proto)
end
Range.__proto.__each = function(self)
   local inc = self[3]
   local cur = self[1] - inc
   local max = self[2]
   return function()
      cur = cur + inc
      if cur <= max then
         return cur
      end
   end
end
Range.__proto.iter = Range.__proto.__each
Range.__proto.each = function(self, block)
   for i in Range.__proto.iter(self) do
      block(i)
   end
end
Range.__proto.check = function(self, val)
   if type(tonumber(val)) ~= 'number' then return false end
   if val < self[1] then return false end
   if val > self[2] then return false end
   if val % self[3] == 0 then return true end
   return false
end
Range.__proto.coerce = function(self, val)
   if not self:check(val) then
      throw(TypeError:new(tostring(val).." is not in: "..tostring(self)))
   end
   return val
end

Void = newtype"Void"
Void.check = function(self, ...)
   return select("#", ...) == 0
end

Nil = newtype"Nil"
Nil.__proto.__tostring = nil
Nil.__proto.__call = nil
Nil.check = function(self, val)
   if val == nil then return true end
end
debug.setmetatable(nil, Nil.__proto)

Number = newtype"Number"
Number.check = function(self, val)
   return rawtype(val) == 'number'
end
Number.coerce = function(self, val)
   local v = tonumber(val)
   if not self:check(v) then
      throw(TypeError:new("cannot coerce '"..tostring(val).."' to Number"), 2)
   end
   return v
end
Number.__proto.__tostring = nil
Number.__proto.toString = tostring
Number.__proto.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
Number.__proto.__bnot = bit.bnot
Number.__proto.__bor  = bit.bor
Number.__proto.__band = bit.band
Number.__proto.__bxor = bit.bxor
Number.__proto.__lshift = bit.lshift
Number.__proto.__rshift = bit.rshift
Number.__proto.__arshift = bit.arshift
debug.setmetatable(0, Number.__proto)

String = newtype"String"
String.__proto.__tostring = nil
String.check  = function(self, that)
   return rawtype(that) == 'string'
end
String.coerce = function(self, that)
   return tostring(that)
end
for k,v in pairs(string) do
   String.__proto[k] = v
end
String.__proto.__type = String
String.__proto.__index = lookup(String.__proto)
String.__proto.toString = function(self) return self end
String.__proto.__match = function(a, b)
   if Pattern.type(b) == 'pattern' then
      return b:match(a)
   else
      return a == b
   end
end
String.__proto.__getitem = function(self, idx)
   return self:sub(idx, idx + 1)
end
String.__proto.split = function(str, sep, max)
   if not str:find(sep) then
      return Array:new(str)
   end
   if max == nil or max < 1 then
      max = 0
   end
   local pat = "(.-)"..sep.."()"
   local idx = 0
   local list = Array:new()
   local last
   for part,pos in _each(str:gmatch(pat)) do
      idx = idx + 1
      list[idx] = part
      last = pos
      if idx == max then
         break
      end
   end
   if idx ~= max then
      list[idx + 1] = str:sub(last)
   end 
   return list
end
String.__proto.len = function(self)
   return #self
end
debug.setmetatable("", String.__proto)

Boolean = newtype"Boolean"
Boolean.__proto.__tostring = nil
Boolean.check = function(self, that)
   return rawtype(that) == 'boolean'
end
Boolean.coerce = function(self, v)
   return not(not(v))
end
Boolean.__proto.toString = function(self) return tostring(self) end
debug.setmetatable(true, Boolean.__proto)

Function = newtype"Function"
Function.__proto.__call = nil
Function.__proto.__tostring = nil
Function.__proto.dump = string.dump
Function.check = function(self, that)
   return rawtype(that) == 'function'
end
Function.__proto.__name = '<function>'
Function.__proto.toString = function(self) return tostring(self) end
debug.setmetatable(function() end, Function.__proto)

Thread = newtype"Thread"
Thread.__tostring = nil
Thread.yield = coroutine.yield
Thread.wrap  = coroutine.wrap
Thread.check = function(self, that)
   return rawtype(that) == 'thread'
end
Thread.coerce = function(self, code)
   if self:check(code) then return code end
   if rawtype(code) ~= "function" then
      throw(TypeError:new("cannot coerce "..tostring(code).." to Thread"), 2)
   end
   return coroutine.wrap(code)
end
Thread.new = function(type, ...)
   return type.create(...)
end
Thread.__proto.toString = function(self) return tostring(self) end
for k,v in pairs(coroutine) do
   if not rawget(Thread,k) then
      Thread.__proto[k] = v
   end
end
debug.setmetatable(coroutine.create(function() end), Thread.__proto)

Pattern = newtype"Pattern"
Pattern.__proto = getmetatable(_patt.P(1))
Pattern.__proto.__type = Pattern
Pattern.__proto.__index = lookup(Pattern.__proto.__index)
Pattern.toString = function() return '<type Pattern>' end
for k,v in pairs(Meta) do
   Pattern.__proto[k] = v
end
for k,v in pairs(_patt) do
   Pattern[k] = v
end
Pattern.__proto.apply = function(patt, self, subj, ...)
   return patt:match(subj, ...)
end
Pattern.__proto.__match = function(patt, subj)
   return patt:match(subj)
end

Error = class(__env, "Error", nil, {}, function(__env,self)
   has(self, "trace", nil, function(self) return end)
   method(self,'init',function(self, message, level)
      if not level then level = 1 end
      self:__set_trace(debug.traceback(message, level + 1))
   end)
   method(self,'raise', function(self, message, level)
      if not level then level = 1 end
      error(self:new(message, level + 1), level + 1)
   end, true)
   method(self,'toString',function(self)
      return tostring(typeof(self).__name)..": "..tostring(self:trace())
   end)
   method(self, '__extend__', function(self, that)
      if not rawget(that, 'raise') then
         that.raise = self.raise
      end
   end, true)
end)

SyntaxError  = class(__env, "SyntaxError",  Error, {}, function() end)
AccessError  = class(__env, "AccessError",  Error, {}, function() end)
ImportError  = class(__env, "ImportError",  Error, {}, function() end)
ExportError  = class(__env, "ExportError",  Error, {}, function() end)
TypeError    = class(__env, "TypeError",    Error, {}, function() end)
NameError    = class(__env, "NameError",    Error, {}, function() end)
ComposeError = class(__env, "ComposeError", Error, {}, function() end)

function evaluate(lua)
   local main = assert(loadstring(lua))
   local fenv = setmetatable({ }, { __index = __env })
   fenv.self = fenv
   setfenv(main, fenv)
   return xpcall(main, function(err,...)
      print(debug.traceback(err, 3))
      os.exit(1)
   end, __env)
end

int8 = ffi.typeof('int8_t')
uint8 = ffi.typeof('uint8_t')

int16 = ffi.typeof('int16_t')
uint16 = ffi.typeof('uint16_t')

int32 = ffi.typeof('int32_t')
uint32 = ffi.typeof('uint32_t')

int64 = ffi.typeof('int64_t')
uint64 = ffi.typeof('uint64_t')

do
   -- from strict.lua
   local mt = getmetatable(_G)
   if mt == nil then
      mt = { }
      setmetatable(_G, mt)
   end

   mt.__declared = { }

   local function what()
      local d = debug.getinfo(3, "S")
      return d and d.what or "C"
   end

   mt.__newindex = function(t, n, v)
      if not mt.__declared[n] then
         local w = what()
         if w ~= "main" and w ~= "C" then
            error("assign to undeclared variable '"..tostring(n).."'", 2)
         end
         mt.__declared[n] = true
      end
      rawset(t, n, v)
   end

   mt.__index = function(t, n)
      if not mt.__declared[n] and what() ~= "C" then
         error("variable '"..tostring(n).."' is not declared", 2)
      end
      return rawget(t, n)
   end
end

__env.global = __env
return __env

