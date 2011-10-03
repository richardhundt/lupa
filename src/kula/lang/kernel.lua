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
   return rawget(meta, key)
end
Type.does = function(this, that)
   if getmetatable(that) ~= Trait then
      error(string.format("TypeError: %s is not a trait", tostring(that)), 2)
   end
   local meta = getmetatable(this)
   local does = rawget(meta, '__does')
   return does and does[that.__body]
end

Method = setmetatable({ }, Type)
Method.__tostring = function(self)
   return '<method>'..self.name
end
Method.__call = function(self, ...)
   return self.code(...)
end
Method.new = function(self, name, code, with)
   self.__index = self
   local meth = setmetatable({
      name = name,
      code = code,
   }, self)
   if with then
      for i=1, #with do
         with[i]:__extend(meth)
      end
   end
   return meth
end
Method.__extend = function(self, base)
   base[self.name] = self.code
end
Method.get = function(self, obj)
   return function(...) return self.code(obj, ...) end
end
Method.set = function(self, obj, val)
   rawset(obj, self.name, val)
end

readonly = { }
readonly.__extend = function(self, attr)
   attr.set = function(self, obj)
      error(string.format('AccessError: %s is readonly', self.name), 2)
   end
end

Slot = { }
Slot.__tostring = function(self)
   return '@'..self.name
end
Slot.new = function(self, name, default, guard, with)
   self.__index = self
   local attr = setmetatable({
      name    = name,
      default = default,
      guard   = guard,
      __does  = { },
   }, self)
   if with then
      for i=1, #with do
         if not with[i].__extend then
            error("TypeError: "..tostring(with[i]).." cannot extend", 2)
         end
         with[i]:__extend(attr)
      end
   end
   return attr
end
Slot.__extend = function(self, base)
   base[self.name] = self.default()
end
Slot.get = function(self, obj)
   local val = obj[self.name]
   if val == nil then
      val = self.default()
      obj[self.name] = val
   end
   return val
end
Slot.set = function(self, obj, val)
   if self.guard then
      obj[self.name] = self.guard:__coerce(val)
   else
      obj[self.name] = val
   end
end


Needs = { }
Needs.__tostring = function(self)
   return 'needs '..self.name..':'..tostring(self.guard and self.guard.__name or 'Any')
end
Needs.new = function(self, name, guard)
   self.__index = self
   return setmetatable({ name = name, guard = guard }, self)
end
Needs.__extend = function(self, base)
   local found
   for i=1, #base do
      local slot = base[i]
      if slot.name == self.name and getmetatable(slot) ~= Needs then
         found = slot
         break
      end
   end
   if not found then
      error(string.format('CompositionError: missing member %q',self.name), 3)
   end
end

Rule = setmetatable({ }, Type)
Rule.__name = 'Rule'
Rule.__tostring = function(self) return 'rule '..tostring(self.name) end
Rule.new = function(self, name, patt, with)
   self.__index = self
   local rule = setmetatable({
      name = name,
      patt = patt,
   }, self)
   if with then
      for i=1, #with do
         with[i]:__extend(rule)
      end
   end
   return rule
end
Rule.__extend = function(self, base)
   base[self.name] = self.patt
end
Rule.get = function(self, obj)
   local key = self.name
   if not rawget(obj, key) then
      local base = getmetatable(obj)
      local gram = { key }
      for i=1, #base do
         if getmetatable(base[i]) == Rule then
            gram[base[i].name] = base[i].patt
         end
      end
      rawset(obj, key, LPeg.P(gram))
   end
   return obj[key]
end
Rule.set = function(self, obj, val)
   local key = self.name
   if not (type(val) == 'userdata' and LPeg.type(val) == 'pattern') then
      error(string.format("TypeError: %s is not a pattern", tostring(val)), 2)
   end
   obj[key] = val
end

Super = setmetatable({ }, Type)
Super.__tostring = function(self)
   return 'super '..self.__name
end

Missing = setmetatable({ }, Type)
Missing.__call = function(self)
   error("AccessError: attempt to call method "..tostring(self.name), 2)
end
Missing.__index = { }
Missing.__index.get = function(self, obj)
   error("AccessError: attempt to get "..tostring(self.name), 2)
end
Missing.__index.set = function(self, obj, val)
   error("AccessError: attempt to set "..tostring(self.name), 2)
end

Object = {
   Method:new("isa", Type.isa),
   Method:new("can", Type.can),
   Method:new("does", Type.does),
}
Object.__index = function(self, key)
   return setmetatable({ name = key }, Missing)
end

setmetatable(Object, Type)
Object.new = function(self, name, base, body, with)
   if base and getmetatable(base) ~= Class then
      base = getmetatable(base)
   end
   local anon = Class:new('#'..name, base, body, with)
   anon.__tostring = function() return 'object '..name end
   local inst = anon:new()
   return inst
end

STable = setmetatable({ }, Type)
STable.new = function(self, base)
   local stab = { unpack(base) }
   for i=1, #stab do
      local slot = stab[i]
      stab[slot.name] = slot
   end
   setmetatable(stab, self)
   return stab
end
STable.__index = function(self, key)
   return setmetatable({ name = key }, Missing)
end

Class = setmetatable({ }, Type)
Class.__coerce = function(self, that)
   if not Type.isa(that, self) then
      error('GuardError: cannot coerce '..tostring(that)..' to '..tostring(self))
   end
   return that
end
Class.__tostring = function(self)
   return 'class '..(rawget(self,'__name') or '<anon>')
end
Class.new = function(self, name, base, body, with)
   if not base then
      base = Object
   end

   local super = STable:new(base)
   local slots = STable:new(base)
   local class = {
      __name = name,
      __body = body,
      __base = base,
      __stab = slots,
      __does = { },
      unpack(base)
   }

   class.__index = class

   if with then
      for i=1, #with do
         local trait = with[i]
         Trait.__extend(trait, class)
      end
   end

   class.__setslot = function(obj, key, val)
      slots[key]:set(obj, val)
   end
   class.__getslot = function(obj, key)
      return slots[key]:get(obj)
   end

   class.bless = function(self, that)
      self.__index = self
      return setmetatable(that or { }, self)
   end
   class.new = function(self, ...)
      local obj = self:bless({ })
      if rawget(self, '__init') ~= nil then
         self.__init(obj, ...)
      end
      return obj
   end

   class.__tostring = function(self)
      return 'object '..tostring(name)
   end

   local seen = { }
   for i=1, #super do
      local slot = super[i]
      slot:__extend(super)
      slot:__extend(class)
      seen[slot] = true
   end
   setmetatable(super, Super)
   setmetatable(class, Class)

   body(class, super)

   for i=1, #class do
      local slot = class[i]
      if not seen[slot] then
         slot:__extend(class)
         slots[slot.name] = slot
      end
   end

   return class
end

Trait = setmetatable({ }, Type)
Trait.__coerce = function(self, that)
   local with = that.__does
   if with and with[self.__body] then
      return that
   end
   error('GuardError: '..tostring(that)..' does not compose '..tostring(self))
end
Trait.__tostring = function(self)
   return 'trait '..self.__name
end
Trait.new = function(self, name, want, body, with, ...)
   self.__index = self
   local trait = setmetatable({
      __name  = name,
      __body  = body,
      __want  = want,
      __does  = { },
   }, Trait)

   if want == 0 then
      body(trait, ...)
   end

   return trait
end
Trait.__make = function(self, ...)
   local want = self.__want - select('#', ...)
   local copy = Trait:new(self.__name, want, self.__body, nil, ...)
   for i=1, #self do
      copy[i] = self[i]
   end
   return copy
end
Trait.__extend = function(self, into)
   if self.__want and self.__want > 0 then
      error(string.format(
         "CompositionError: %s expects %s parameters",
         tostring(self), self.__want
      ), 2)
   end
   into.__does[self.__body] = true
   for i=1, #self do
      into[#into + 1] = self[i]
   end
end

Guard = setmetatable({ }, Type)
Guard.__tostring = function(self)
   return '<guard>'..self.__name
end
Guard.new = function(self, name, body)
   return setmetatable({
      __name = name,
      __coerce = function(self, ...)
         return body(...)
      end,
   }, self)
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
guard = function(...)
   return Guard:new(...)
end
method = function(base, name, code, with)
   base[#base + 1] = Method:new(name, code, with)
end
has = function(base, name, default, guard, with)
   base[#base + 1] = Slot:new(name, default, guard, with)
end
needs = function(base, name, guard)
   base[#base + 1] = Needs:new(name, guard)
end
rule = function(base, name, patt, with)
   base[#base + 1] = Rule:new(name, patt, with)
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

Number = setmetatable({
   __coerce = function(_,v)
      local n = tonumber(v)
      if n == nil then
         error("GuardError: cannot coerce "..tostring(v).." to Number", 2)
      end
      return n
   end,
}, Type)
Number.__name = 'Number'
Number.__index = Number
Number.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
debug.setmetatable(0, Number)

String = setmetatable({
   __coerce = function(_,v)
      if type(v) == 'nil' then
         error('TypeError: attempt to coerce a nil value to String', 2)
      end
      return tostring(v)
   end,
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


Boolean = setmetatable({
   __coerce = function(_,v) return not(not v) end,
}, Type)
Boolean.__name = 'Boolean'
Boolean.__index = Boolean
debug.setmetatable(true, Boolean)

Function = setmetatable({
   __coerce = function(_,v) return assert(loadstring(v)) end,
}, Type)
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

None = setmetatable({
   __coerce = function(_, ...)
      if select('#',...) > 0 then
         error('GuardError: got a value where None expected', 2)
      end
   end
}, Type)

Some = setmetatable({
   __coerce = function(_, ...)
      if select('#',...) < 1 then
         error('GuardError: got no value where Some expected', 2)
      end
   end
}, Type)

nilOk = function(guard)
   return setmetatable({
      __coerce = function(_, ...)
         if ... == nil then return ... end
         return guard:__coerce(...)
      end
   }, Type)
end

magic = _G

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
         Type.can(obj, key)
      ) ~= nil
   end,

   coerce = function(guard, ...)
      return guard:__coerce(...)
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

      local o = { __name = tostring(getmetatable(a))..' with '..tostring(b) }

      -- shallow copy a into o
      for k,v in pairs(a) do o[k] = v end

      -- install slots from b
      for i=1, #b do b[i]:__extend(o) end
      Trait.__extend(b, o)

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

