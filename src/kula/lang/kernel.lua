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
Type.__index = { }
Type.__index.isa = function(this, that)
   local base = this
   while base do
      if base == that then return true end
      base = base.__base
      if not base then break end
   end
   return false
end
Type.__index.can = function(obj, key)
   return obj[key]
end
Type.__tostring = function(self)
   return 'type '..(getmetatable(self).__name or 'Type')
end

Object = setmetatable({ }, Type)
Object.__name = 'Object'
Object.__tostring = function(self)
   return 'object '..tostring(getmetatable(self))
end
Object.__index = { }
Object.__index.isa = function(this, that)
   local base = getmetatable(this)
   while base do
      if base == that then return true end
      base = base.__base
      if not base then break end
   end
   return false
end
Object.__index.can = function(obj, key)
   return obj[key]
end
Object.new = function(self)
   local obj = { }
   obj.__index = obj
   return setmetatable(obj, Object)
end

Class = setmetatable({ }, Type)
Class.new = function(self, name, base, body, with)
   if not base then base = Object end
   if type(base) ~= 'table' then
      error("TypeError: cannot inherit from "..tostring(base), 2)
   end
   if rawget(base, '__index') == nil then
      base.__index = base
   end

   local class = {
      __name = name,
      __base = base,
   }

   local proto = setmetatable({ }, base)
   local super = setmetatable({ }, base)

   class.__index = proto
   class.__tostring = function(self)
      return 'object '..tostring(name)
   end

   setmetatable(class, Class)

   if with then
      for i=1, #with do
         with[i]:compose(class)
      end
   end

   body(class, super)

   return class
end
Class.__tostring = function(self)
   return 'class '..(self.__name or '<anon>')
end
Class.__index = setmetatable({ }, Object)
Class.__index.bless = function(self, that)
   return setmetatable(that or { }, self)
end
Class.__index.new = function(self, ...)
   local obj = self:bless({ })
   if obj.__init ~= nil then
      obj:__init(...)
   end
   return obj
end

Trait = setmetatable({ }, Type)
Trait.__call = function(self, ...)
   local copy = Trait:new(self.__name, self.__body, self.__with)
   local make = self.compose
   local args = { ... }
   copy.compose = function(self, into)
      return make(self, into, unpack(args))
   end
   return copy
end
Trait.__tostring = function(self)
   return 'trait '..self.__name
end
Trait.new = function(self, name, body, with)
   local trait = setmetatable({
      __name = name,
      __body = body,
      __with = with,
   }, Trait)
   return trait
end
Trait.__index = { }
Trait.__index.compose = function(self, into, ...)
   for i=1, #self.__with do
      self.__with[i]:compose(into)
   end
   self.__body(into, ...)
   return into
end

class = function(...)
   return Class:new(...)
end
trait = function(...)
   return Trait:new(...)
end
object = function(...)
   local anon = Class:new(...)
   local inst = anon:new()
   inst.__index = inst
   return inst
end
method = function(base, name, code, meta)
   local into = meta and base or base.__index
   into[name] = code
end
has = function(base, name, default, meta)
   local into = meta and base or base.__index
   local setter = '__set_'..name
   local getter = '__get_'..name
   into[setter] = function(obj, val)
      obj[name] = val
   end
   into[getter] = function(obj)
      local val = obj[name]
      if val == nil then
         val = default()
         obj[setter](obj, val)
      end
      return val
   end
end
rule = function(into, name, patt, meta)
   local into = meta and base or base.__index
   local setter = '__set_'..name
   local getter = '__get_'..name
   into[name] = patt
   into[setter] = function(obj, val)
      assert(LPeg.type(patt) == 'pattern', 'TypeError: not a pattern')
      obj[name] = val
   end
   into[getter] = function(obj)
      local val = rawget(obj,name)
      if val == nil then
         local grammar = { name }
         for k,p in pairs(into) do
            if LPeg.type(p) == 'pattern' then
               grammar[k] = p
            end
         end
         val = LPeg.P(grammar)
         obj[setter](obj, val)
      end
      return val
   end
end

Hash = setmetatable({ }, Type)
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
Hash.__index = setmetatable({ }, Object)
Hash.__index.__getitem = rawget
Hash.__index.__setitem = rawset
Hash.__each = pairs

Array = setmetatable({ }, Type)
Array.__name = 'Array'
Array.new = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.__size = function(self)
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

Array.__index = setmetatable({ }, Object)
Array.__index.__getitem = rawget
Array.__index.__setitem = rawset
Array.__index.__get_size = function(self, name)
   return #self
end
Array.__index.unpack = unpack
Array.__index.insert = table.insert
Array.__index.remove = table.remove
Array.__index.concat = table.concat
Array.__index.sort   = table.sort
Array.__index.each = function(self, block)
   for i=1, #self do block(self[i]) end
end
Array.__index.map = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.__index.grep = function(self, block)
   local out = Array:new()
   for i=1, #self do
      local v = self[i]
      if block(v) then
         out[#out + 1] = v
      end
   end
   return out
end
Array.__index.push = function(self, v)
   self[#self + 1] = v
end
Array.__index.pop = function(self)
   local v = self[#self]
   self[#self] = nil
   return v
end
Array.__index.shift = function(self)
   local v = self[1]
   for i=2, #self do
      self[i-1] = self[i]
   end
   self[#self] = nil
   return v
end
Array.__index.unshift = function(self, v)
   for i=1, #self + 1 do
      self[i+1] = self[i]
   end
   self[1] = v
end
Array.__index.reverse = function(self)
   local out = Array:new()
   for i=1, #self do
      out[i] = self[(#self - i) + 1]
   end
   return out
end

Range = setmetatable({ },Type)
Range.__name = 'Range'
Range.__index = setmetatable({ }, Object)
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
Range.__index.each = function(self, block)
   for i in Range:__each() do
      block(i)
   end
end

Nil = setmetatable({ }, Type)
Nil.__name = 'Nil'
debug.setmetatable(nil, Nil)

Number = setmetatable({ }, Type)
Number.__name = 'Number'
Number.__index = setmetatable({ }, Object)
Number.__index.times = function(self, block)
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
String.__index = setmetatable({ }, Object)

for k,v in pairs(string) do String.__index[k] = v end
do
   local strfind, strgmatch, strsub = string.find, string.gmatch, string.sub
   String.__index.split = function(str, sep, max)
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
Boolean.__index = setmetatable({ }, Object)
debug.setmetatable(true, Boolean)

Function = setmetatable({ }, Type)
Function.__name = 'Function'
Function.__index = setmetatable({ }, Object)
Function.__index.__get_gen = function(self)
   return coroutine.wrap(self)
end
debug.setmetatable(function() end, Function)

Coroutine = setmetatable({ }, Type)
Coroutine.__name = 'Coroutine'
Coroutine.__index = setmetatable({ }, Object)
for k,v in pairs(coroutine) do
   Coroutine.__index[k] = v
end
debug.setmetatable(coroutine.create(function() end), Coroutine)

Tuple = setmetatable({ }, Type)
Tuple.__name = "Tuple"
Tuple.new = function(self, ...)
   return setmetatable({ size = select('#', ...), ... }, Tuple)
end
Tuple.__index = setmetatable({ }, Object)
Tuple.__index.__getitem = rawget
Tuple.__spread = unpack
Tuple.__size = function(self)
   return self.size
end

Pattern = setmetatable(getmetatable(LPeg.P(1)), Type)
Pattern.__call = function(patt, subj)
   return patt:match(subj)
end
Pattern.__match = function(patt, subj)
   return patt:match(subj)
end
setmetatable(Pattern.__index, Object)

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
         if type(this[k]) ~= type(v) then
            return false
         end
         if not this[k]:isa(getmetatable(v)) then
            return false
         end
      end
      return true
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

   each = function(a, ...)
      if type(a) == 'function' then return a, ... end
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

