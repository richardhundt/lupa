module("kula.lang.kernel", package.seeall)

require"kula.lang.strict"

local math = math
--local ffi = require'ffi'
local bit = require"bit"
LPeg = require"lpeg"

local
   getmetatable,
   setmetatable,
   rawget,
   rawset,
   pairs,
   ipairs,
   tonumber,
   tostring,
   assert,
   type
   =
   getmetatable,
   setmetatable,
   rawget,
   rawset,
   pairs,
   ipairs,
   tonumber,
   tostring,
   assert,
   type


Core = _M

Type = { }
Type.__name = 'Type'
Type.__index = Type
Type.isa = function(this, that)
   local base = getmetatable(this)
   while base do
      if base == that then return true end
      base = rawget(base, '__base')
      if not base then break end
   end
   return false
end
Type.can = function(obj, key)
   local can = rawget(obj, key)
   if can ~= nil then return can end
   local meta = getmetatable(obj)
   if getmetatable(meta) == Type then meta = obj end
   return rawget(meta.__proto, key)
end

Object = setmetatable({ }, Type)
Object.__proto = Object
Object.__index = Object.__proto

Object.new = function(self, name, base, body, with)
   local anon = Class:new('#'..name, base, body, with)
   local inst = anon:new()
   inst.__proto = inst
   return inst
end

Class = setmetatable({ }, Type)
Class.__tostring = function(self)
   return 'class '..(rawget(self,'__name') or '<anon>')
end
Class.__index = Class
Class.new = function(self, name, base, body, with)
   if not base then base = Object end

   local class = {
      __name = name,
      __body = body,
      __base = base,
   }

   local proto = setmetatable({ }, { __index = base.__proto })
   class.__proto = proto
   class.__index = function(obj, key)
      local method = proto[key]
      if method then return method end
      local __missing = proto.__missing
      if __missing then
         return __missing(obj, key)

      end
      error("AccessError: no such member "..key.." in "..tostring(obj), 2)
   end

   local super = setmetatable({ }, { __index = base.__proto })

   if with then
      for i=1, #with do
         local trait = with[i]
         Trait.__extend(trait, proto)
      end
   end

   class.bless = function(self, that)
      return setmetatable(that or { }, self)
   end

   class.new = function(self, ...)
      local obj = self:bless({ })
      if rawget(self.__proto, '__init') ~= nil then
         self.__proto.__init(obj, ...)
      end
      return obj
   end

   class.__tostring = function(self)
      return 'object '..tostring(name)
   end

   setmetatable(class, Class)

   body(class, super)

   return class
end

Trait = setmetatable({ }, Type)
Trait.__tostring = function(self)
   return 'trait '..self.__name
end
Trait.new = function(self, name, want, body, with, ...)
   self.__index = self
   local trait = setmetatable({
      __name  = name,
      __body  = body,
      __want  = want,
      __proto = { },
   }, Trait)

   if want == 0 then
      body(trait, ...)
   end

   return trait
end
Trait.__make = function(self, ...)
   local want = self.__want - select('#', ...)
   return Trait:new(self.__name, want, self.__body, nil, ...)
end
Trait.__extend = function(self, into)
   if self.__want and self.__want > 0 then
      error(string.format(
         "CompositionError: %s expects %s parameters",
         tostring(self), self.__want
      ), 2)
   end
   for k,v in pairs(self.__proto) do
      into.__proto[k] = v
   end
end

class = function(...)
   return Class:new(...)
end
trait = function(...)
   return Trait:new(...)
end
object = function(...)
   return Object:new(...)
end
method = function(base, name, code, meta)
   local into = meta and base or base.__proto
   into[name] = code
end
has = function(base, name, default, meta)
   local into = meta and base or base.__proto
   into['__set_'..name] = function(obj, val)
      obj[name] = val
   end
   into['__get_'..name] = function(obj)
      local val = rawget(obj,name)
      if val == nil then return default() end
      return val
   end
end
rule = function(base, name, patt, meta)
   local into = meta and base or base.__proto
   into['__set_'..name] = function(obj, val)
      assert(LPeg.type(patt) == 'pattern', 'TypeError: not a pattern')
      obj[name] = val
   end
   into['__get_'..name] = function(obj)
      local val = rawget(obj,name)
      if val == nil then return patt end
      return val
   end
end

Hash = setmetatable({ }, Type)
Hash.__index = Hash
Hash.new = function(self, table)
   return setmetatable(table or { }, self)
end
Hash.__tostring = function(self)
   local buf = { }
   for k, v in pairs(self) do
      local _v
      if type(v) == 'string' then
         _v = string.format('%q', v)
      else
         _v = tostring(v)
      end
      if type(k) == 'string' then
         buf[#buf + 1] = k..'='.._v
      else
         buf[#buf + 1] = '['..tostring(k)..']='..tostring(_v)
      end
   end
   return '{'..table.concat(buf, ',')..'}'
end
Hash.__getitem = rawget
Hash.__setitem = rawset
Hash.__each = pairs

Array = setmetatable({ }, Type)
Array.__name = 'Array'
Array.__index = Array
Array.new = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.__getitem = rawget
Array.__setitem = rawset
Array.__size = function(self)
   return #self
end
Array.__get_size = function(self, name)
   return #self
end
Array.__tostring = function(self)
   local buf = { }
   for i=1, #self do
      if type(self[i]) == 'string' then
         buf[#buf + 1] = string.format('%q', self[i])
      else
         buf[#buf + 1] = tostring(self[i])
      end
   end
   return '['..table.concat(buf,',')..']'
end
Array.__each = ipairs
Array.__spread = unpack
Array.unpack = unpack
Array.insert = table.insert
Array.remove = table.remove
Array.concat = table.concat
Array.sort   = table.sort
Array.each = function(self, block)
   for i=1, #self do block(self[i]) end
end
Array.map = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.grep = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v = self[i]
      if block(v) then
         out[#out + 1] = v
      end
   end
   return out
end
Array.push = function(self, v)
   self[#self + 1] = v
end
Array.pop = function(self)
   local v = self[#self]
   self[#self] = nil
   return v
end
Array.shift = function(self)
   local v = self[1]
   for i=2, #self do
      self[i-1] = self[i]
   end
   self[#self] = nil
   return v
end
Array.unshift = function(self, v)
   for i=1, #self + 1 do
      self[i+1] = self[i]
   end
   self[1] = v
end
Array.reverse = function(self)
   local out = Array:new()
   for i=1, #self do
      out[i] = self[(#self - i) + 1]
   end
   return out
end

Range = setmetatable({ },Type)
Range.__index = Range
Range.__name = 'Range'
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
Range.each = function(self, block)
   for i in self:__iter() do
      block(i)
   end
end

Nil = setmetatable({ }, Type)
Nil.__name = 'Nil'
debug.setmetatable(nil, Nil)

Number = setmetatable({ }, Type)
Number.__name = 'Number'
Number.__index = Number
Number.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
debug.setmetatable(0, Number)

String = setmetatable({
   __match = function(a,p)
      return LPeg.P(p):match(a)
   end
}, Type)
String.__name = 'String'
String.__index = String

for k,v in pairs(string) do String[k] = v end
do
   local strfind, strgmatch, strsub = string.find, string.gmatch, string.sub
   String.split = function(str, sep, max)
      if not strfind(str, sep) then
         return { str }
      end
      if max == nil or max < 1 then
         max = 0
      end
      local pat = "(.-)"..sep.."()"
      local idx = 0
      local list = { }
      local last
      for part, pos in strgmatch(str, pat) do
         idx = idx + 1
         list[idx] = part
         last = pos
         if idx == max then break end
      end
      if idx ~= max then
         list[idx + 1] = strsub(str, last)
      end
      return list
   end
end
debug.setmetatable("", String)


Boolean = setmetatable({ }, Type)
Boolean.__name = 'Boolean'
Boolean.__index = Boolean
debug.setmetatable(true, Boolean)

Function = setmetatable({ }, Type)
Function.__name = 'Function'
Function.__index = Function
Function.__get_gen = function(code)
   return coroutine.wrap(code)
end
debug.setmetatable(function() end, Function)

Coroutine = setmetatable({ }, Type)
Coroutine.__name = 'Coroutine'
Coroutine.__index = Coroutine
for k,v in pairs(coroutine) do
   Coroutine[k] = v
end
debug.setmetatable(coroutine.create(function() end), Coroutine)

Tuple = setmetatable({ }, Type)
Tuple.__name = "Tuple"
Tuple.__index = Tuple
Tuple.new = function(self, ...)
   self.__index = self
   return setmetatable({ size = select('#', ...), ... }, Tuple)
end
Tuple.__getitem = rawget
Tuple.__spread = unpack
Tuple.__size = function(self)
   return self.size
end

Pattern = setmetatable(getmetatable(LPeg.P(1)), Type)
Pattern.__call = function(patt, subj)
   return patt:match(subj)
end
Pattern.__index.__match = function(patt, subj)
   return patt:match(subj)
end

import = function(from, ...)
   local num = select('#', ...)
   local mod = load(from)
   local out = { }
   for i,sym in ipairs{ ... } do
      out[i] = rawget(mod, sym)
   end
   return unpack(out,1,num)
end

load = function(from)
   local path = from
   if type(from) == 'table' then
      path = table.concat(from, '.')
   end
   return require(path)
end

Package = { }
Package.__tostring = function(self)
   local path = Package.get_path(self)
   return '<package>'..table.concat(path, '::')
end
Package.new = function(self, name, base)
   if not name then name = '<main>' end
   local pkg = {
      __name    = name,
      __parent  = base,
      __environ = { },
   }

   local outer
   if base then
      outer = base.__environ
   else
      outer = _M
   end

   setmetatable(pkg.__environ, {
      __index = outer,
      __newindex = function(env, key, val)
         rawset(env, key, val)
         rawset(pkg, key, val)
      end,
   })

   return setmetatable(pkg, self)
end

Package.MAIN = Package:new()

Package.get_path = function(self)
   local path = { }
   if rawget(self, '__name') ~= '<main>' then
      path[#path + 1] = rawget(self, '__name')
   end
   local base = rawget(self, '__parent')
   while base do
      local name = rawget(base, '__name')
      if name == '<main>' then break end
      table.insert(path, 1, name)
      base = rawget(base, '__parent')
   end
   return path
end

package = function(outer, path, body)
   local curr = Package.MAIN
   local canon_path = Package.get_path(outer)
   for i=1, #path do
      canon_path[#canon_path + 1] = path[i]
   end
   for i=1, #canon_path do
      local name = canon_path[i]
      if rawget(curr, name) == nil then
         local pckg = Package:new(name, curr)
         curr.__environ[name] = pckg
      end
      curr = curr[name]
   end
   _G.package.loaded[table.concat(canon_path, '.')] = curr
   _G.package.loaded[table.concat(canon_path, '::')] = curr
   setfenv(body, curr.__environ)
   return body(curr)
end

unit = function(main, modname, ...)
   setfenv(main, Package.MAIN.__environ)
   main(Package.MAIN)
   return Package.MAIN
end

eval = function(source, env, name)
   local eval = kula.lang.make_eval(source, name)
   if env then
      setfenv(eval, env)
   end
   return eval()
end

Op = {
   as     = setmetatable,
   typeof = getmetatable,
   yield  = coroutine.yield,
   throw  = function(raise, trace) error(raise, 2) end,

   contains = function(key, obj)
      return (
         rawget(obj, key) or
         rawget(obj, '__get_'..key) or
         rawget(getmetatable(obj), '__get_'..key) or
         Type.can(obj, key)
      ) ~= nil
   end,

   like = function(this, that)
      for k,v in pairs(that) do
         local this_v = rawget(this, k)
         if getmetatable(v) == Class then
            if not Type.isa(this_v, v) then
               return false
            end
         elseif getmetatable(v) == Trait then
            if not Type.does(this_v, v) then
               return false
            end
         elseif getmetatable(v) ~= getmetatable(this_v) then
            return false
         elseif v ~= this_v then
            return false
         end
      end
      return true
   end,

   make = function(self, ...)
      local meta = getmetatable(self)
      if meta and meta.__make then
         return meta.__make(self, ...)
      elseif self.__make then
         return self:__make(...)
      else
         error("ComposeError: cannot compose "..tostring(self), 2)
      end
      return made
   end,

   with = function(a, b)
      if getmetatable(b) ~= Trait then
         error(string.format('TypeError: %s is not a trait', tostring(b)), 2)
      end
      if type(a) ~= 'table' then
         error(string.format('TypeError: cannot compose into a %s', type(a)), 2)
      end

      local o = {
         __name = tostring(getmetatable(a))..' with '..tostring(b)
      }

      -- shallow copy a into o
      for k,v in pairs(a) do o[k] = v end

      -- install slots from b
      for k,v in pairs(b) do o[k] = v end

      setmetatable(o, getmetatable(a))

      -- o now quacks like a, but it has a new identity
      return o
   end,

   spread = function(a)
      local __spread = rawget(getmetatable(a), '__spread')
      if __spread then return __spread(a) end
      return unpack(a)
   end,

   size = function(a)
      local __size = rawget(getmetatable(a), '__size')
      if __size then return __size(a) end
      return #a
   end,

   each = function(a)
      if type(a) == 'function' then return a end
      local __each = rawget(getmetatable(a), '__each')
      if __each then return __each(a) end
      return pairs(a)
   end,

   lshift = function(a,b)
      local __lshift = rawget(getmetatable(a), '__lshift')
      if __lshift then return __lshift(a, b) end
      return bit.lshift(a, b)
   end,
   rshift = function(a,b)
      local __rshift = rawget(getmetatable(a), '__rshift')
      if __rshift then return __rshift(a, b) end
      return bit.rshift(a, b)
   end,
   arshift = function(a,b)
      local __arshift = rawget(getmetatable(a), '__arshift')
      if __arshift then return __arshift(a, b) end
      return bit.arshift(a, b)
   end,
   bor = function(a,b)
      local __bor = rawget(getmetatable(a), '__bor')
      if __bor then return __bor(a, b) end
      return bit.bor(a, b)
   end,
   bxor = function(a,b)
      local __bxor = rawget(getmetatable(a), '__bxor')
      if __bxor then return __bxor(a, b) end
      return bit.bxor(a, b)
   end,
   bnot = function(a)
      local __bnot = rawget(getmetatable(a), '__bnot')
      if __bnot then return __bnot(a) end
      return bit.bnot(a)
   end,
   match = function(a,b)
      local __match = rawget(getmetatable(a), '__match')
      if __match then return __match(a, b) end
      return a == b
   end,
   getitem = function(o, k)
      local __getitem = rawget(getmetatable(o), '__getitem')
      if __getitem then return __getitem(o, k) end
      return o[k]
   end,
   setitem = function(o, k, v)
      local __setitem = rawget(getmetatable(o), '__setitem')
      if __setitem then __setitem(o, k, v) return end
      o[k] = v
   end,
}

do
   local function capt_hash(tab) return Core.Hash:new(tab) end
   LPeg.Ch = function(patt) return LPeg.Ct(patt) / capt_hash end

   local function capt_array(tab) return Core.Array:new(unpack(tab)) end
   LPeg.Ca = function(patt) return LPeg.Ct(patt) / capt_array end
   local Predef = { nl = LPeg.P("\n") }
   local any = LPeg.P(1)

   LPeg.locale(Predef)

   Predef.a = Predef.alpha
   Predef.c = Predef.cntrl
   Predef.d = Predef.digit
   Predef.g = Predef.graph
   Predef.l = Predef.lower
   Predef.p = Predef.punct
   Predef.s = Predef.space
   Predef.u = Predef.upper
   Predef.w = Predef.alnum
   Predef.x = Predef.xdigit
   Predef.A = any - Predef.a
   Predef.C = any - Predef.c
   Predef.D = any - Predef.d
   Predef.G = any - Predef.g
   Predef.L = any - Predef.l
   Predef.P = any - Predef.p
   Predef.S = any - Predef.s
   Predef.U = any - Predef.u
   Predef.W = any - Predef.w
   Predef.X = any - Predef.x

   LPeg.Predef = Predef
   LPeg.Def = function(id)
      if Predef[id] == nil then
         error("No predefined pattern '"..tostring(id).."'", 2)
      end
      return Predef[id]
   end
end

