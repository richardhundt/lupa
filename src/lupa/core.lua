local __env = setmetatable({ }, { __index = _G })
package.loaded['lupa.core'] = __env
setfenv(1, __env)
for k,v in pairs(_G) do __env[k] = v end

local bit = require("bit")
local ffi = require('ffi')

package.path  = ';;./lib/?.lua;./src/?.lua;'..package.path
package.cpath = ';;./lib/?.so;'..package.cpath

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
   __call = function(self, ...) return self:apply(...) end;
   __tostring = function(self) return self:toString() end;
}

function environ(outer)
   if not outer then outer = __env end
   return setmetatable({ }, { __index = outer })
end

local function lookup(slots)
   return function(self, key)
      local val = slots[key]
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
         throw(TypeError:new("Cannot extend "..tostring(from), 2))
      end
   end

   local class = { }
   local slots = { }
   local rules = { }

   class.__name = name
   class.__from = from
   class.__size = from.__size
   class.__with = { }
   class.__need = { }
   class.__body = body

   class.__slots = setmetatable(slots, { __index = from.__slots })
   class.__index = lookup(slots)

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
      class[k] = v
   end
   setmetatable(class, Class)

   if with then
      for i=1,#with do
         if typeof(with[i]) ~= Trait then
            throw(TypeError:new(tostring(with[i]).." is not a trait"), 2)
         end
         with[i]:make(class.__inner, class)
      end
   end

   local super = setmetatable({ }, from)
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
         if class.__slots[k] == nil then
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
   setmetatable(trait, Trait)
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
   inst.__slots.toString = function(self)
      return ('%s<object %s>: %p'):format(type(self), tostring(name), self)
   end
   inst.__slots.members = function(self)
      return self.__slots
   end
   setmetatable(inst, inst)
   if inst.__slots.init then
      inst.__slots.init(inst)
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
      into.__slots[name] = get
      into.__slots['__set_'..name] = set
   end
end

function method(into, name, code, meta)
   if meta then
      into[name] = code
   else
      into.__slots[name] = code
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

   into.__slots[name] = get
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
         return setmetatable(tab, Table)
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
         return setmetatable(tab, Array)
      end
   end

   _patt.Ch = function(patt,init)
       return Pattern.__div(_patt.Ct(patt), make_capt_hash(init))
   end
   _patt.Ca = function(patt,init)
       return Pattern.__div(_patt.Ct(patt), make_capt_array(init))
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
   local mod = __load(from)
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

function __load(from)
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

function typeof(this)
   if type(this) == 'cdata' then
      return ffi.typeof(this)
   else
      return getmetatable(this)
   end
end

throw = error

function __len__(this)
   if type(this) == 'table' then
      local mt = typeof(this)
      local __len = mt and rawget(mt, '__len')
      if __len then return __len(this) end
      return #this
   else
      return #this
   end
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
   local __each = mt and rawget(mt, "__each")
   if __each then
      return __each(a)
   end
   return pairs(a)
end
function __is__(this, that)
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
   local __match = mt and rawget(mt, '__match')
   if __match then return __match(this, that) end
   return this == that
end

function __bnot__(this)
   local mt = typeof(this)
   local __bnot = mt and rawget(mt, '__bnot')
   if __bnot then return __bnot(this) end
   return bit.bnot(tonumber(this))
end

function __bor__(this, that)
   local mt = typeof(this)
   local __bor = mt and rawget(mt, '__bor')
   if __bor then return __bor(this, that) end
   return bit.bor(tonumber(this), tonumber(that))
end
function __band__(this, that)
   local mt = typeof(this)
   local __band = mt and rawget(mt, '__band')
   if __band then return __band(this, that) end
   return bit.band(tonumber(this), tonumber(that))
end
function __bxor__(this, that)
   local mt = typeof(this)
   local __bxor = mt and rawget(mt, '__bxor')
   if __bxor then return __bxor(this, that) end
   return bit.bxor(tonumber(this), tonumber(that))
end
function __lshift__(this, that)
   local mt = typeof(this)
   local __lshift = mt and rawget(mt, '__lshift')
   if __lshift then return __lshift(this, that) end
   return bit.lshift(tonumber(this), tonumber(that))
end
function __rshift__(this, that)
   local mt = typeof(this)
   local __rshift = mt and rawget(mt, '__rshift')
   if __rshift then return __rshift(this, that) end
   return bit.rshift(tonumber(this), tonumber(that))
end
function __arshift__(this, that)
   local mt = typeof(this)
   local __arshift = mt and rawget(mt, '__arshift')
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
Any.__slots = { }
Any.__index = lookup(Any.__slots)
Any.__match = function(a, b)
   if typeof(b) == Class or typeof(b) == Trait or typeof(b) == Type then
      return b:check(a)
   end
   return a == b
end
Any.__slots.apply = function(self)
   error(tostring(self).." is not callable", 2)
end
Any.__slots.toString = function(self)
   return ('%s%s: %p'):format(type(self), tostring(typeof(self)), self)
end
Any.__slots.is = function(self, that)
   return that:check(self)
end
Any.__slots.can = function(self, key)
   return typeof(self).__slots[key] ~= nil
end
Any.__slots.does = function(self, that)
   return typeof(self).__with[that.__body] ~= nil
end

Type = setmetatable({ }, Meta)
Type.__name  = "Type"
Type.new = function(meta, name)
   local type = { }
   type.__name = name
   type.__from = Any
   type.__need = { }
   type.__with = { }
   type.__body = function() end
   type.__size = 0
   type.__rules = { }
   type.__slots = setmetatable({ }, { __index = Any.__slots })
   type.__index = lookup(type.__slots)
   type.toString = function() return '<type '..name..'>' end

   for k,v in pairs(Meta) do type[k] = v end
   return setmetatable(type, meta)
end
Type.toString = function() return '<type Type>' end
Type.__slots = setmetatable({ }, { __index = Any.__slots })
Type.__index = lookup(Type.__slots)
Type.__slots.check = function(self, that)
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
Type.__slots.coerce = function(self, ...)
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
for k,v in pairs(Meta) do Type[k] = v end

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
Enum.__slots = setmetatable({ }, { __index = Type.__slots })
Enum.__index = lookup(Enum.__slots)
Enum.__slots.coerce = function(self, that)
   if not self:check(that) then
      throw(TypeError:new(tostring(that).." is not a member of "..tostring(self), 2), 2)
   end
   return that
end
Enum.__slots.check = function(self, that)
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
Class.__slots = setmetatable({ }, { __index = Type.__slots })
Class.__index = lookup(Class.__slots)
Class.__slots.toString = function(self)
   return "<class "..tostring(self.__name)..">"
end
Class.__slots.new = function(self, ...)
   local obj = setmetatable({ }, self)
   if self.__slots.init then
      self.__slots.init(obj, ...)
   end
   return obj
end
Class.__slots.members = function(self)
   return self.__slots
end

Trait = newtype"Trait"
Trait.__index = lookup(Trait.__slots)
Trait.__slots.toString = function(self)
   return "<trait "..tostring(self.__name)..">"
end
Trait.__slots.check = function(self, that)
   return that.__with[self.__body] ~= nil
end
Trait.__slots.coerce = function(self, that)
   if not self:check(that) then
      throw(TypeError:new(tostring(that).." does not compose: "..tostring(self), 2))
   end
   return that
end
Trait.__slots.__getitem = function(self, ...)
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
Trait.__slots.make = function(self, into, recv, ...)
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
   return setmetatable({ ... }, self)
end
Array.apply = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.__getitem = function(self, type)
   return guard('Array['..tostring(type.__name)..']', function(self, samp)
      for i=1, #samp do
         samp[i] = type:coerce(samp[i])
      end
      return samp
   end)
end
Array.__index = Array.__slots
Array.__slots.len = function(self)
   return #self
end
Array.__slots.apply = function(self, ...)
   local recv = self[1]
   local args = { unpack(self, 2) }
   for i=1, select('#', ...) do
      args[#args + 1] = select(i, ...)
   end
   return self[1](unpack(args))
end
Array.__slots.toString = function(self)
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
Array.__each = ipairs
Array.__slots.__getitem = rawget
Array.__slots.__setitem = rawset
Array.__match = function(a, b)
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
Array.__add = function(a, b)
   local c = Array:new(unpack(a))
   for i=1, #b do c[#c + 1] = b[i] end
   return c
end
Array.__slots.unpack = unpack
Array.__slots.insert = table.insert
Array.__slots.remove = table.remove
Array.__slots.concat = table.concat
Array.__slots.sort = function(self, cond)
   table.sort(self, cond)
   return self
end
Array.__slots.each = function(self, block)
   for i=1, #self do
      block(self[i])
   end
   return self
end
Array.__slots.map = function(self, block)
   local out = Array:new()
   for i = 1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.__slots.inject = function(self, code)
   for i=1, #self do
      self[i] = code(self[i])
   end
   return self
end
Array.__slots.grep = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v=self[i]
      if block(v) then
         out[#out + 1] = v
      end
   end
   return out
end
Array.__slots.push = function(self, v)
   self[#self + 1] = v
end
Array.__slots.pop = function(self)
   return table.remove(self)
end
Array.__slots.shift = function(self)
   return table.remove(self, 1)
end
Array.__slots.unshift = function(self, v)
   table.insert(self, 1, v)
end
Array.__slots.splice = function(self, offset, count, ...)
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
Array.__slots.reverse = function(self) 
   local out = Array:new()
   for i=1, #self do
      out[i] = self[#self - i + 1]
   end
   return out
end

Table = newtype"Table"
Table.new = function(self, table)
   return setmetatable(table or { }, self)
end
Table.apply = function(self, ...)
   return self:new(...)
end
Table.MODE = { k = { }, v = { }, kv = { } } 
Table.__index = Table.__slots
Table.__slots.weak = function(self, mode)
   if mode == 'k' or mode == 'kv' or mode == 'v' then
      debug.setmetatable(self, Table.MODE[mode])
      return self
   end
   error("invalid weak mode '"..tostring(mode).."', must be 'k', 'kv' or 'v'", 2)
end
Table.__slots.next = next
Table.__slots.as = function(this, that)
   return setmetatable(this, that)
end
Table.__slots.toString = function(self)
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
Table.__each = pairs
Table.__slots.len = function(self) return #self end
Table.__slots.each = function(self)
   return pairs(self)
end
Table.__slots.__getitem = rawget
Table.__slots.__setitem = rawset

for k,v in pairs(table) do Table.__slots[k] = v end
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
   return setmetatable({ min, max, inc }, self)
end
Range.__each = function(self)
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
Range.__slots.iter = Range.__each
Range.__slots.each = function(self, block)
   for i in Range.__slots.iter(self) do
      block(i)
   end
end
Range.__slots.check = function(self, val)
   if type(tonumber(val)) ~= 'number' then return false end
   if val < self[1] then return false end
   if val > self[2] then return false end
   if val % self[3] == 0 then return true end
   return false
end
Range.__slots.coerce = function(self, val)
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
Nil.__tostring = nil
Nil.__call = nil
Nil.check = function(self, val)
   if val == nil then return true end
end
debug.setmetatable(nil, Nil)

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
Number.__tostring = nil
Number.__slots.toString = tostring
Number.__slots.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
Number.__bnot = bit.bnot
Number.__bor  = bit.bor
Number.__band = bit.band
Number.__bxor = bit.bxor
Number.__lshift = bit.lshift
Number.__rshift = bit.rshift
Number.__arshift = bit.arshift
debug.setmetatable(0, Number)

String = newtype"String"
String.__tostring = nil
String.check  = function(self, that)
   return rawtype(that) == 'string'
end
String.coerce = function(self, that)
   return tostring(that)
end
for k,v in pairs(string) do
   String.__slots[k] = v
end
String.__slots.toString = function(self) return self end
String.__add = function(a, b) return a .. tostring(b) end
String.__match = function(a, b)
   if Pattern.type(b) == 'pattern' then
      return b:match(a)
   else
      return a == b
   end
end
String.__getitem = function(self, idx)
   return self:sub(idx, idx + 1)
end
String.__slots.split = function(str, sep, max)
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
String.__slots.len = function(self)
   return #self
end
debug.setmetatable("", String)

Boolean = newtype"Boolean"
Boolean.__tostring = nil
Boolean.check = function(self, that)
   return rawtype(that) == 'boolean'
end
Boolean.coerce = function(self, v)
   return not(not(v))
end
Boolean.__slots.toString = function(self) return tostring(self) end
debug.setmetatable(true, Boolean)

Function = newtype"Function"
Function.__call = nil
Function.__tostring = nil
Function.__slots.dump = string.dump
Function.check = function(self, that)
   return rawtype(that) == 'function'
end
Function.__slots.__name = '<function>'
Function.__slots.toString = function(self) return tostring(self) end
--[[
Function.__slots.coerce = function(self, ...)
   return self(...)
end
Function.__slots.check = function(self, ...)
   return (pcall(self, ...))
end
--]]
debug.setmetatable(function() end, Function)

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
Thread.__slots.toString = function(self) return tostring(self) end
for k,v in pairs(coroutine) do
   if not rawget(Thread,k) then
      Thread.__slots[k] = v
   end
end
debug.setmetatable(coroutine.create(function() end), Thread)

Pattern = setmetatable(typeof(_patt.P(1)), Type)
Pattern.__name = "Pattern"
Pattern.__from = Any
Pattern.__with = { }
Pattern.__slots = setmetatable(Pattern.__index, { __index = Any.__slots })
Pattern.__index = lookup(Pattern.__slots)
Pattern.toString = function() return '<type Pattern>' end
for k,v in pairs(Meta) do
   Pattern[k] = v
end
for k,v in pairs(_patt) do
   Pattern[k] = v
end
Pattern.__slots.apply = function(patt, self, subj, ...)
   return patt:match(subj, ...)
end
Pattern.__match = function(patt, subj)
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

