module("kula.lang.kernel", package.seeall)

require"kula.lang.strict"

local math = math
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
Type.__call = function(self, ...)
   return self:__apply(...)
end
Type.isa = function(self, that)
   return getmetatable(self) == that
end
Type.can = function(self, key)
   return rawget(getmetatable(self), key)
end
Type.does = function(self, that)
   return false
end
Type.__index = function(self, key)
   local val = Type[key]
   if val == nil then
      error("AccessError: no such member "..key.." in "..tostring(self), 2)
   end
   return val
end
Type.__tostring = function(self)
   return 'type '..(self.__name or 'Type')
end

Class = setmetatable({ }, Type)
Class.__tostring = function(self)
   return self.__name
end
Class.__index = function(self, key)
   error("AccessError: no such member "..key.." in "..self.__name, 2)
end
Class.__call = function(self, ...)
   return self:__apply(...)
end

Object = setmetatable({ }, Class)
Object.__name = 'Object'
Object.__from = { }
Object.__with = { }
Object.__tostring = function(self)
   return '<object '..tostring(getmetatable(self))..'>'
end
Object.__index = Object
Object.isa = function(self, that)
   local meta = getmetatable(self)
   return meta == that or (meta.__from and (meta.__from[that] ~= nil))
end
Object.can = function(self, key)
   local meta = getmetatable(self)
   return rawget(meta, key)
end
Object.does = function(self, that)
   return self.__with[that.__body] ~= nil
end

Trait = setmetatable({ }, Type)
Trait.__call = function(self, ...)
   local copy = trait(nil, self.__name, self.__body, self.__with)
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
Trait.__index = Trait
Trait.__index.compose = function(self, into, ...)
   for i=1, #self.__with do
      self.__with[i]:compose(into)
   end
   self.__body(into, ...)
   into.__with[self.__body] = true
   return into
end

class = function(into, name, from, with, body)
   if #from == 0 then
      from[#from + 1] = Object
   end
   local class = {
      __name = name,
      __from = from,
   }

   local super = { }
   local queue = { unpack(from) }
   while #queue > 0 do
      local base = table.remove(queue, 1)
      if getmetatable(base) ~= Class then
         error("TypeError: "..tostring(base).." is not a Class", 2)
      end
      from[base] = true
      for k,v in pairs(base) do
         if class[k] == nil then class[k] = v end
         if super[k] == nil then super[k] = v end
      end
      if base.__from then
         for i=1, #base.__from do
            queue[#queue + 1] = base.__from[i]
         end
      end
   end

   class.__index = class
   class.__apply = function(self, ...)
      local obj = setmetatable({ }, self)
      if rawget(self, '__init') ~= nil then
         local ret = obj:__init(...)
         if ret ~= nil then
            return ret
         end
      end
      return obj
   end

   setmetatable(class, Class)

   if with then
      for i=1, #with do
         with[i]:compose(class)
      end
   end

   into[name] = class
   body(class, super)
   return class
end
trait = function(into, name, with, body)
   local trait = setmetatable({
      __name = name,
      __body = body,
      __with = with,
   }, Trait)
   if into then
      into[name] = trait
   end
   return trait
end
object = function(into, name, from, ...)
   for i=1, #from do
      if getmetatable(from[i]) ~= Class then
         from[i] = getmetatable(from[i])
      end
   end
   local anon = class(into,'#'..name, from, ...)
   local inst = anon()
   if into then
      into[name] = inst
   end
   return inst
end
method = function(into, name, code)
   into[name] = code
   local setter = '__set_'..name
   local getter = '__get_'..name
   into[getter] = function(obj)
      return function(...)
         return code(obj, ...)
      end
   end
   into[setter] = function(obj, code)
      method(obj, name, code)
   end
end
has = function(into, name, default)
   local setter = '__set_'..name
   local getter = '__get_'..name
   into[setter] = function(obj, val)
      obj[name] = val
   end
   into[getter] = function(obj)
      local val = rawget(obj,name)
      if val == nil then
         val = default()
         obj[setter](obj, val)
      end
      return val
   end
end
grammar = function(into, name, body)
   local grammar = { }
   body(grammar)
   into[name] = LPeg.P(grammar)
end
rule = function(into, name, patt)
   if name == '__init' or into[1] == nil then
      into[1] = name
   end
   into[name] = patt
end

Hash = setmetatable({ }, Type)
Hash.__name = 'Hash'
Hash.__index = Hash
Hash.__apply = function(self, table)
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
Array.__apply = function(self, ...)
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
Array.__getitem = rawget
Array.__setitem = rawset
Array.__get_size = function(self, name)
   return #self
end
Array.unpack = unpack
Array.insert = table.insert
Array.remove = table.remove
Array.concat = table.concat
Array.sort   = table.sort
Array.each = function(self, block)
   for i=1, #self do block(self[i]) end
end
Array.map = function(self, block)
   local out = Array()
   for i=1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.grep = function(self, block)
   local out = Array()
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
   local out = Array()
   for i=1, #self do
      out[i] = self[(#self - i) + 1]
   end
   return out
end

Range = setmetatable({ },Type)
Range.__name = 'Range'
Range.__index = Range
Range.__apply = function(self, min, max, inc)
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
   for i in Range.__each(self) do
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
   for i=1, self do block(i) end
end
debug.setmetatable(0, Number)

String = setmetatable({ }, Type)
String.__name = 'String'
String.__index = String
String.__match = function(a,p)
   return LPeg.P(p):match(a)
end
for k,v in pairs(string) do
   String[k] = v
end
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
debug.setmetatable("", String)

Boolean = setmetatable({ }, Type)
Boolean.__name = 'Boolean'
Boolean.__index = Boolean
debug.setmetatable(true, Boolean)

Function = setmetatable({ }, Type)
Function.__name = 'Function'
Function.__index = Function
Function.__get_gen = function(self)
   return coroutine.wrap(self)
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
Tuple.__apply = function(self, ...)
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
Pattern.__match = function(patt, subj)
   return patt:match(subj)
end

import = function(from, ...)
   local num = select('#', ...)
   local mod = load(from)
   if num > 0 then
      local out = { }
      for i,sym in ipairs{ ... } do
         out[i] = rawget(mod, sym)
      end
      return unpack(out,1,num)
   end
   return mod
end

load = function(from)
   local path = from
   if type(from) == 'table' then
      path = table.concat(from, '.')
   end
   local mod = require(path)
   if mod == true then
      mod = _G
      for i=1, #from do
         mod = mod[from[i]]
      end
   end
   return mod
end

Package = setmetatable({ }, Type)
Package.__tostring = function(self)
   local path = table.concat(Package.get_path(self), '::')
   if path == '' then
      return 'package <main>'
   else
      return 'package '..path
   end
end
Package.__apply = function(self, name, base)
   local pkg = {
      __name   = name or '<main>',
      __parent = base or _M,
   }
   return setmetatable(pkg, self)
end
Package.__index = function(self, key)
   return self.__parent[key]
end

Package.MAIN = Package()

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
         local pckg = Package(name, curr)
         curr[name] = pckg
      end
      curr = curr[name]
   end
   _G.package.loaded[table.concat(canon_path, '.')] = curr
   _G.package.loaded[table.concat(canon_path, '::')] = curr
   setfenv(body, curr)
   return body(curr)
end

unit = function(main, modname, ...)
   setfenv(main, Package.MAIN)
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
      return (rawget(obj, key) or rawget(getmetatable(obj), key)) ~= nil
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
   local function capt_hash(tab) return Core.Hash(tab) end
   LPeg.Ch = function(patt) return LPeg.Ct(patt) / capt_hash end

   local function capt_array(tab) return Core.Array(unpack(tab)) end
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

