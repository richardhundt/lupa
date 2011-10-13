package.path = ";;./src/?.lua;./lib/?.lua;"..package.path
package.cpath = ";;./lib/?.so;"..package.cpath

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

__class = function(into, name, from, with, body)
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
__trait = function(into, name, with, body)
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
__object = function(into, name, from, ...)
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
__method = function(into, name, code)
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
__has = function(into, name, default)
   local setter = '__set_'..name
   local getter = '__get_'..name
   into[setter] = function(obj, val)
      obj[name] = val
   end
   into[getter] = function(obj)
      local val = rawget(obj,name)
      if val == nil then
         val = default(obj)
         obj[setter](obj, val)
      end
      return val
   end
end
__grammar = function(into, name, body)
   local gram = { }
   local patt
   function gram:match(...)
      return patt:match(...)
   end
   body(gram)
   do
      local grmr = { }
      for k,v in pairs(gram) do
         if __patt.type(v) == 'pattern' then
            grmr[k] = v
         end
      end
      grmr[1] = rawget(gram, 1) or '__init'
      patt = __patt.P(grmr)
   end
   into[name] = gram
end
__rule = function(into, name, patt)
   if name == '__init' or rawget(into,1) == nil then
      into[1] = name
   end
   into[name] = patt
   local rule_name = '__rule_'..name
   into['__get_'..name] = function(self)
      local rule = rawget(self, rule_name)
      if rule == nil then
         local grmr = { }
         for k,v in pairs(self) do
            if __patt.type(v) == 'pattern' then
               grmr[k] = v
            end
         end
         grmr[1] = name
         rule = __patt.P(grmr)
         rawset(self, rule_name, rule)
      end
      return rule
   end
end

__patt = require"lpeg"
do
   local function capt_hash(tab) return Hash(tab) end
   __patt.Ch = function(patt) return __patt.Ct(patt) / capt_hash end

   local function capt_array(tab) return Array(unpack(tab)) end
   __patt.Ca = function(patt) return __patt.Ct(patt) / capt_array end
   local predef = { nl = __patt.P("\n"), pos = __patt.Cp() }
   local any = __patt.P(1)

   __patt.locale(predef)

   predef.a = predef.alpha
   predef.c = predef.cntrl
   predef.d = predef.digit
   predef.g = predef.graph
   predef.l = predef.lower
   predef.p = predef.punct
   predef.s = predef.space
   predef.u = predef.upper
   predef.w = predef.alnum
   predef.x = predef.xdigit
   predef.A = any - predef.a
   predef.C = any - predef.c
   predef.D = any - predef.d
   predef.G = any - predef.g
   predef.L = any - predef.l
   predef.P = any - predef.p
   predef.S = any - predef.s
   predef.U = any - predef.u
   predef.W = any - predef.w
   predef.X = any - predef.x

   __patt.predef = predef
   __patt.Def = function(id)
      if predef[id] == nil then
         error("No predefined pattern '"..tostring(id).."'", 2)
      end
      return predef[id]
   end
end

_G.__main = _G
_G.__main.__env = _G

__unit = function(main, ...)
   return __package(_G, "__main", main)
end
__package = function(into, name, body)
   local path = { }
   for frag in name:gmatch("([^%.]+)") do
      path[#path + 1] = frag
   end
   local pckg = _G.__main
   for i=1, #path do
      local name = path[i]
      if rawget(pckg, name) == nil then
         local pkg = { }
         local env = { }
         setmetatable(env, {
            __index = function(env, key)
               local val = pkg[key]
               if val ~= nil then return val end
               return into.__env[key]
            end,
            __newindex = function(env, key, val)
               rawset(env, key, val)
               rawset(pkg, key, val)
            end,
         })
         setmetatable(pkg, {
            __newindex = function(pkg, key, val)
               env[key] = val
            end
         })
         pkg.__env = env
         pckg[name] = pkg
      end
      pckg = pckg[name]
   end
   into[name] = pckg
   package.loaded[name] = pckg
   if body then
      setfenv(body, pckg.__env)
      body(pckg)
   end
   return pckg
end
__import = function(into, from, what, dest)
   local mod = __load(from)
   if what then
      if what:isa(Array) then
         if dest then
            into = __package(into, dest)
         end
         for i=1, #what do
            into[what[i]] = mod[what[i]]
         end
      elseif what:isa(Hash) then
         for n,a in pairs(what) do
            into[a] = what[n]
         end
      end
   else
      return mod
   end
end

__load = function(from)
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

__op_as     = setmetatable
__op_typeof = getmetatable
__op_yield  = coroutine.yield

__op_in = function(key, obj)
   return (rawget(obj, key) or rawget(getmetatable(obj), key)) ~= nil
end
__op_like = function(this, that)
   for k,v in pairs(that) do
      if type(this[k]) ~= type(v) then
         return false
      end
      if not this[k]:isa(getmetatable(v)) then
         return false
      end
   end
   return true
end
__op_spread = function(a)
   local __spread = rawget(getmetatable(a), '__spread')
   if __spread then return __spread(a) end
   return unpack(a)
end
__op_each = function(a, ...)
   if type(a) == 'function' then return a, ... end
   local __each = rawget(getmetatable(a), '__each')
   if __each then return __each(a) end
   return pairs(a)
end
__op_lshift = function(a,b)
   local __lshift = rawget(getmetatable(a), '__lshift')
   if __lshift then return __lshift(a, b) end
   return bit.lshift(a, b)
end
__op_rshift = function(a,b)
   local __rshift = rawget(getmetatable(a), '__rshift')
   if __rshift then return __rshift(a, b) end
   return bit.rshift(a, b)
end
__op_arshift = function(a,b)
   local __arshift = rawget(getmetatable(a), '__arshift')
   if __arshift then return __arshift(a, b) end
   return bit.arshift(a, b)
end
__op_bor = function(a,b)
   local __bor = rawget(getmetatable(a), '__bor')
   if __bor then return __bor(a, b) end
   return bit.bor(a, b)
end
__op_bxor = function(a,b)
   local __bxor = rawget(getmetatable(a), '__bxor')
   if __bxor then return __bxor(a, b) end
   return bit.bxor(a, b)
end
__op_bnot = function(a)
   local __bnot = rawget(getmetatable(a), '__bnot')
   if __bnot then return __bnot(a) end
   return bit.bnot(a)
end

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
   return Type[key]
   --[[
   local val = Type[key]
   if val == nil then
      error("AccessError: no such member "..key.." in "..tostring(self), 2)
   end
   return val
   --]]
end
Type.__tostring = function(self)
   return 'type '..(rawget(self, '__name') or 'Type')
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
   local copy = trait(nil, self.__name, self.__with, self.__body)
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
Array.sort = table.sort
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
   for i=#self+1,1,-1 do
      self[i] = self[i-1]
   end
   self[1] = v
end
Array.splice = function(self, offset, count, ...)
   local out = Array()
   for i=offset, offset + count - 1 do
      out:push(self:remove(offset))
   end
   for i=select('#', ...), 1, -1 do
      self:insert(offset, (select(i, ...)))
   end
   return out
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
Nil.__index = Nil
debug.setmetatable(nil, Nil)

Number = setmetatable({ }, Type)
Number.__name = 'Number'
Number.__index = Number
Number.times = function(self, block)
   for i=1, self do block(i) end
end
debug.setmetatable(0, Number)

String = setmetatable(string, Type)
String.__name = 'String'
String.__index = String
String.__match = function(a,p)
   return __patt.P(p):match(a)
end
String.split = function(str, sep, max)
   if not str:find(sep) then
      return Array(str)
   end
   if max == nil or max < 1 then
      max = 0
   end
   local pat = "(.-)"..sep.."()"
   local idx = 0
   local list = Array()
   local last
   for part, pos in str:gmatch(pat) do
      idx = idx + 1
      list[idx] = part
      last = pos
      if idx == max then break end
   end
   if idx ~= max then
      list[idx + 1] = str:sub(last)
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

Pattern = setmetatable(getmetatable(__patt.P(1)), Type)
Pattern.__call = function(patt, subj)
   return patt:match(subj)
end
Pattern.__match = function(patt, subj)
   return patt:match(subj)
end

