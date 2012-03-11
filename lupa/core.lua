local __env = setmetatable({ }, { __index = _G })
setfenv(1, __env)
package.cpath = ';;./lib/?.so;'..package.cpath

local bit = require("bit")
local ffi = require('ffi')

do
   local fh  = io.open('./include/uv.h')
   local def = fh:read('*a')
   fh:close()
   ffi.cdef(def)
   __system = assert(ffi.load('./lib/libuv.so'))
end

newtable  = loadstring("return {...}")
local rawget, rawset = rawget, rawset

local uv = assert(ffi.load('./lib/libuv.so'))
local loop = uv.uv_loop_new()

local _tostring = tostring
function tostring(obj)
   local mt = getmetatable(obj)
   local __tostring = mt.__slots and mt.__slots.__tostring
   if __tostring then
      return __tostring(obj)
   end
   return _tostring(obj)
end

function __class(into, name, from, with, body)
   if #from == 0 then
      from[#from + 1] = Object
   end

   local class = { }
   local slots = STable(class)

   class.__name  = name
   class.__from  = from
   class.__slots = slots

   local queue = { unpack(from) }
   while #queue > 0 do
      local base = table.remove(queue, (1))
      local meta = getmetatable(base)
      if meta ~= Class and meta ~= Type then
         __op_throw(TypeError(tostring(base).." is not a Class or Type", 2))
      end
      from[base] = true
      slots[base.__name] = Super(base)
      for k,v in pairs(base.__slots) do
         if rawget(slots, k) == nil then slots[k] = v end
      end
      for k,v in pairs(base) do
         if rawget(class, k) == nil then class[k] = v end
      end
      if base.__from then
         for i=1, #base.__from do
            queue[#queue + 1] = base.__from[i]
         end
      end
   end

   class.__index = function(obj, key)
      local slot = slots[key]
      return slot:get(obj, key)
   end

   class.__newindex = function(obj, key, val)
      local slot = slots[key]
      slot:set(obj, key, val)
   end

   class.__in = function(obj, key)
      return slots[key] ~= nil
   end

   class.new = function(self, ...)
      local obj = setmetatable({ }, self)
      if rawget(slots, "__init") ~= nil then
         local ret = obj:__init(...)
         if ret ~= nil then
            return ret
         end
      end
      return obj
   end
   class.__apply = function(self,...)
      return self:new(...)
   end

   setmetatable(class, Class)

   local env = setmetatable({ }, { __index = into })
   if with then
      for i=1,#with do
         with[i]:compose(env, class)
      end
   end

   into[name] = class
   body(env, class)

   return class
end

function __trait(into, name, with, body)
   local trait = { }
   trait.__name = name
   trait.__body = body
   trait.__with = with
   setmetatable(trait, Trait)
   if into then
      into[name] = trait
   end 
   return trait
end

function __object(into, name, from, with, body)
   for i=1, #from do
      if getmetatable(from[i]) ~= Class then
         from[i] = getmetatable(from[i])
      end
   end
   local anon = __class(into, "#"..name, from, with, body)
   local inst = setmetatable({ }, anon)
   into[name] = inst
   return inst
end

function __method(into, name, code) 
   into[name] = code
   into.__slots[name] = Method(name, code)
end

function __has(into, name, type, ctor) 
   into.__slots[name] = Slot(name, type, ctor)
end

function __rule(into, name, patt) 
   if name == "__init" or rawget(into, 1) == nil then
      into[1] = name
   end
   local rule = Rule(into, name, patt)
   into.__slots[name] = rule
   into[name] = patt
end

function __try(_try,...)
   local ok, er = pcall(_try)
   if not ok then
      for i=1, select("#",...) do
         local node = select(i,...)
         local body = node.body
         local type = node.type
         if __match(er, type) then
             return body(er)
         end
      end
      error(er, 2)
   end
end

__patt = require("lpeg")
__patt.setmaxstack(1024)
do
   local function make_capt_hash(init)
       return function(tab)
         if init ~= nil then
            for k,v in __op_each(init) do
               if tab[k] == nil then
                  tab[k] = v
               end
            end
         end
         return __op_as(tab, Hash)
      end
   end
   local function make_capt_array(init)
       return function(tab)
         if init ~= nil then
            for i=(1),#(init) do
               if tab[i] == nil then
                  tab[i] = init[i]
               end
            end
         end 
         return __op_as(tab , Array)
      end
   end

   __patt.Ch = function(patt,init)
       return Pattern.__div(__patt.Ct(patt), make_capt_hash(init))
   end
   __patt.Ca = function(patt,init)
       return Pattern.__div(__patt.Ct(patt), make_capt_array(init))
   end

   local predef = { }

   predef.nl  = __patt.P("\n")
   predef.pos = __patt.Cp()

   local any=__patt.P(1)
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

function __import(into, from, what, dest) 
   local mod = __load(from)
   if what then
      if dest then
         into[dest] = { }
         into = into[dest]
      end 
      if #what == 0 then
         for key, val in pairs(mod) do
            into[key] = val
         end
      else
         for i=1, #what do
            local key = what[i]
            local val = rawget(mod, key)
            if val == nil then
               __op_throw( ImportError("'"..tostring(key).."' from '"..tostring(from).."' is nil", 2) )
            end
            into[key] = val
         end
      end
   else
      return mod
   end
end

function __export(...)
   local what = Array(...)
   local exporter = { }
   for i = 1, #what do
      local expt = what[i];
      local key, val = expt[1], expt[2]
      if val == nil then
         __op_throw( ExportError("'"..tostring(key).."' is nil", 2) )
      end
      exporter[key] = val
   end
   return exporter
end

function __load(from)
   local path = from
   if type(from) == "table" then
      path = table.concat(from, ".")
   end
   local mod = require(path)
   if mod == true then
      mod = _G
      for i = 1, #from do
         mod= mod[from[i]]
      end
   end
   return mod
end

function __match(a, b)
   if b == a then
      return true
   end
   local mt = getmetatable(b)
   local __match = mt and rawget(mt, "__match")
   if __match then
      return __match(b, a)
   end
   if a:isa(b) then
      return true
   end
   return false
 end

__op_as     = setmetatable
__op_typeof = getmetatable
__op_yield  = coroutine["yield"]

function __op_throw(err)
   local mt = getmetatable(err)
   local __throw = mt and rawget(mt, "__throw")
   if __throw then
      __throw(err, 2)
   end
   return error(err, 2)
end

function __op_in(key, obj)
   local mt = getmetatable(obj)
   local __in = mt and rawget(mt, "__in")
   if __in then
      return __in(obj, key)
   end
   return rawget(obj, key) ~= nil
end

function __op_like(this, that)
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

function __op_spread(a)
   local mt = getmetatable(a)
   local __spread = mt and rawget(mt, "__spread")
   if __spread then
      return __spread(a)
   end
   return unpack(a)
end

function __op_each(a, ...)
   if type(a) == "function" then
      return a, ...
   end
   local mt = getmetatable(a)
   local __each = mt and rawget(mt, "__each")
   if __each then
      return __each(a)
   end
   return pairs(a)
end

function __op_lshift(a, b)
   local mt = getmetatable(a)
   local __lshift = mt and rawget(mt, "__lshift")
   if __lshift then
      return __lshift(a, b)
   end
   return bit.lshift(a, b)
end

function __op_rshift(a, b)
   local mt = getmetatable(a)
   local __rshift = mt and rawget(mt, "__rshift")
   if __rshift then
      return __rshift(a, b)
   end
   return bit.rshift(a, b)
end

function __op_arshift(a, b)
   local mt = getmetatable(a)
   local __arshift = mt and rawget(mt, "__arshift")
   if __arshift then
      return __arshift(a, b)
   end
   return bit.arshift(a, b)
end

function __op_bor(a, b)
   local mt = getmetatable(a)
   local __bor = mt and rawget(mt, "__bor")
   if __bor then
      return __bor(a, b)
   end
   return bit.bor(a, b)
end

function __op_bxor(a, b) 
   local mt = getmetatable(a)
   local __bxor = mt and rawget(mt, "__bxor")
   if __bxor then
      return __bxor(a, b)
   end
   return bit.bxor(a, b)
end

function __op_band(a,b) 
   local mt = getmetatable(a)
   local __band = mt and rawget(mt, "__band")
   if __band then
      return __band(a, b)
   end
   return bit.band(a, b)
end

function __op_bnot(a)
   local mt = getmetatable(a)
   local __bnot = mt and rawget(mt, "__bnot")
   if __bnot then
      return __bnot(a)
   end
   return bit.bnot(a)
end

Type = { }
Type.__name = ("Type")
Type.__call = function(self, ...)
    return self:__apply(...)
end
Type.isa = function(self, that)
   if that == Any then
      return true
   end
   local meta = getmetatable(self)
   return meta == that
end
Type.can = function(self, key)
   return rawget(self, key) or rawget(getmetatable(self), key)
end
Type.does = function(self, that)
   return false
end
Type.__index = Type
Type.__apply = function(self, name)
   local type = { }
   type.__name = name or self.__name
   return setmetatable(type, self)
end
Type.__tostring = function(self) 
   return "type "..(rawget(self, "__name") or "Type")
end

local MetaType = { }
MetaType.__metatable = Type
setmetatable(Type, MetaType)
MetaType.__call = Type.__call

Super = Type("Super")
Super.__index = Super
Super.__tostring = function(self)
   return "<super "..tostring(self.__name)..">"
end
Super.__apply = function(self, from)
   local super = setmetatable({ }, self)
   super.__from = from
   super.__name = from.__name
   return super
end
Super.__call = function(self, ...)
   return self.__from(...)
end
Super.get = function(self, obj, key)
   local proxy = { }
   local super = self.__from
   setmetatable(proxy, {
      __tostring = function(_)
         return tostring(self)
      end,
      __index = function(_, key)
         return super.__slots[key]:get(obj, key)
      end,
      __newindex = function(_, key, val)
         super.__slots[key]:set(obj, key, val)
      end
   })
   rawset(obj, key, proxy)
   return proxy
end
Super.set = function(self, obj, key, val)
   rawset(obj, key, val)
end

STable = Type("STable")
STable.__index = function(self, key)
   return self.__missing
end
STable.__apply = function(self, class)
   local stab = setmetatable({ }, self)
   stab.__missing = Missing(class)
   return stab
end

Slot = Type("Slot")
Slot.__index = Slot
Slot.__apply = function(self, name, type, ctor)
   local slot = setmetatable({ }, self)
   slot.name = name
   slot.ctor = ctor
   slot.type = type
   return slot
end
Slot.__tostring = function(self)
   return '@'..self.name
end
Slot.get = function(self, obj, key)
   local val = rawget(obj, self)
   if val == nil then
      val = self.ctor(obj)
      self:set(obj, key, val)
   end
   return val
end
Slot.set = function(self, obj, key, val)
   if self.type then
      rawset(obj, self, self.type(val))
   else
      rawset(obj, key, val)
   end
end

Method = Type("Method")
Method.__index = Method
Method.__tostring = function(self)
   return "<Method: "..tostring(self.__name)..">"
end
Method.__call = function(self, ...)
   return self.__code(...)
end
Method.__apply = function(type, name, code)
   local self = setmetatable({ }, type)
   self.__name = name
   self.__code = code
   return self
end
Method.get = function(self, obj, key)
   return self.__code
end

Missing = Type("Missing")
Missing.__tostring = function(self)
   return "<"..tostring(self.__class).."#missing>"
end
Missing.__index = Missing
Missing.__apply = function(type, class)
   local self = setmetatable({ }, type)
   self.__class = class
   return self
end
Missing.get = function(self, obj, key)
   local __getindex = rawget(self.__class, '__getindex')
   if __getindex then
      return __getindex(obj, key)
   end
   __op_throw(AccessError("no such member'"..key.."'", 2))
end
Missing.set = function(self, obj, key, val)
   local __setindex = rawget(self.__class, '__setindex')
   if __setindex then
      __setindex(obj, key, val)
      return
   end
   __op_throw(AccessError("no such member'"..key.."'", 2))
end

Rule = Type("Rule")
Rule.__index = Rule
Rule.__apply = function(type, into, name, patt)
   local self = setmetatable({ }, type)
   self.__name = name
   self.__patt = patt
   self.__into = into
   return self
end
Rule.get = function(self, obj, key)
   local rule = rawget(obj, self)
   if rule == nil then
      local grmr = { }
      for k,v in pairs(self.__into) do
         if __patt.type(v) == "pattern" then
            grmr[k] = v
         end
      end
      grmr[1] = key
      rule = __patt.P(grmr)
      rawset(obj, self, rule)
   end
   return rule
end

Class = Type()
Class.__tostring = function(self) 
  return "<class "..tostring(self.__name)..">"
end
Class.__index = function(self, key)
   __op_throw(AccessError("no such member '"..tostring(key).."' in "..tostring(self.__name), 2))
end
Class.__newindex = function(self, key, val)
   if type(val) == 'function' then
      self.__slots[key] = Method(key, val)
   end
   rawset(self, key, val)
end
Class.__call = function(self,...)
   return self:__apply(...)
end

Object = setmetatable({ }, Class)
Object.__name = "Object"
Object.__from = { }
Object.__with = { }
Object.__slots = STable(Object)
Object.__tostring = function(self)
   return "<object "..tostring(getmetatable(self).__name)..">"
end
Object.__index = Object
Object.isa = function(self, that)
   if that == Any then
      return true
   end
   local meta = getmetatable(self)
   if meta == Class then
      meta = self
   end
   return meta == that or (meta.__from and (meta.__from[that] ~= nil))
end
Object.can = function(self, key)
   local meta = getmetatable(self)
   if meta == Class then
      meta = self
   end 
   return rawget(meta, key)
end
Object.does = function(self, that)
    return self.__with[that.__body] ~= nil
end

Trait = Type()
Trait.__call = function(self, ...)
   local args = Array(...)
   local copy = __trait(nil, self.__name, self.__with, self.__body)
   local make = self.compose
   copy.compose = function(self, into, recv) 
      return make(self, into, recv, __op_spread(args))
   end
   return copy
end
Trait.__tostring = function(self) 
   return "trait "..self.__name
end
Trait.__index = Trait
Trait.compose = function(self, into, recv, ...) 
   for i = 1, #self.__with, 1 do
      self.__with[i]:compose(into, recv)
   end
   self.__body(into, recv, ...)
   recv.__with[self.__body] = (true);
   return into
end

Hash= Type("Hash")
Hash.__index = Hash
Hash.__apply = function(self, table)
   return setmetatable(table or { }, self)
end
Hash.__tostring = function(self)
   local buf = { }
   for k,v in pairs(self) do
      local _v
      if type(v) == "string" then
         _v = string.format("%q", v)
      else
         _v = tostring(v)
      end
      if type(k) == "string" then
         buf[#buf + 1] = k.."=".._v
      else
         buf[#buf + 1] = "["..tostring(k).."]="..tostring(_v)
      end
   end
   return "{"..table.concat(buf, ",").."}"
end
Hash.__getitem = rawget
Hash.__setitem = rawset
Hash.__each = pairs

Array = Type("Array")
Array.__index = Array
Array.__apply = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.__tostring = function(self)
   local buf = { }
   for i = 1, #self do
      if type(self[i]) == "string" then
         buf[#buf + 1] = string.format("%q", self[i])
      else
         buf[#buf + 1] = tostring(self[i])
      end 
   end
   return "["..table.concat(buf, ",").."]"
end
Array.__each = ipairs
Array.__spread = unpack
Array.__getitem = rawget
Array.__setitem = rawset
Array.unpack = unpack
Array.insert = table.insert
Array.remove = table.remove
Array.concat = table.concat
Array.sort = table.sort
Array.each = function(self, block)
   for i=1, #self do
      block(self[i])
   end
end
Array.map = function(self, block)
   local out = Array()
   for i = 1, #self do
      local v = self[i]
      out[#out + 1] = block(v)
   end
   return out
end
Array.inject = function(self, block)
   for i=1, #self do
      self[i] = block(self[i])
   end
   return self
end
Array.grep = function(self, block)
   local out = Array()
   for i=1, #self do
      local v=self[i]
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
      self[i - 1] = self[i]
   end
   self[#self] = nil
   return v
end
Array.unshift = function(self, v)
   for i=#self+1, 1, -1 do
      self[i] = self[i-1]
   end
   self[1] = v
end
Array.splice = function(self, offset, count, ...)
   local args = Array(...)
   local out  = Array()
   for i=offset, offset + count - 1 do
      out:push(self:remove(offset))
   end
   for i=#args, 1, -1 do
      self:insert(offset, args[i]);
   end
   return out
end
Array.reverse = function(self) 
   local out = Array()
   for i=1, #self do
      out[i] = self[#self - i + 1]
   end
   return out
end

Range = Type("Range")
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

Void = Type("Void")
Void.__apply = function(self, ...)
   if select("#", ...) ~= 0 then
      __op_throw(TypeError("value in Void", 2))
   end 
   return ...
end

Any= Type("Any")
Any.__apply = function(self, ...) 
   return ...
end

Nil = Type("Nil")
Nil.__index = function(self, key)
   local val = Type[key]
   if val == nil then
      __op_throw(TypeError("no such member "..tostring(key).." in type Nil", 2))
   end
   return val
end
debug.setmetatable(nil, Nil)

Number = Type("Number")
Number.__index = Number
Number.__apply = function(self, val) 
   local v = tonumber(val)
   if v == nil then
      __op_throw(TypeError("cannot coerce '"..tostring(val).."' to Number", 2))
   end
   return v
end
Number.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
debug.setmetatable(0, Number)

String = Type("String")
for k,v in pairs(string) do
   String[k] = v
end
String.__index = String
String.__apply = function(self, val)
   return tostring(val)
end
String.__match = function(a, p)
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
   for part,pos in __op_each(str:gmatch(pat)) do
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
debug.setmetatable("", String)

Boolean = Type("Boolean")
Boolean.__index = Boolean;
debug.setmetatable(true, Boolean)

Function= Type("Function")
Function.__index = Function
Function.__apply = function(self, code, ...)
   local args = Array(...)
   local Compiler = require('lupa.compiler').Compiler
   code = Compiler:compile(code, "=eval", args)
   local func = assert(loadstring(code, "=eval"))
   return func
end
debug.setmetatable(function() end, Function)

Coroutine = Type("Coroutine")
Coroutine.__index = Coroutine
for k,v in pairs(coroutine) do
   Coroutine[k] = v
end
debug.setmetatable(coroutine.create(function() end), Coroutine)

Pattern = setmetatable(getmetatable(__patt.P(1)), Type)
Pattern.__call = function(patt, self, subj, ...)
   return patt:match(subj, ...)
end
Pattern.__match = function(patt, subj)
   return patt:match(subj)
end

__class(__env, "Error", {}, {}, function(__env, self)
   __has(self, "level",   nil, function(self) return 1 end)
   __has(self, "message", nil, function(self) return "unknown" end)
   __has(self, "info",    nil, function(self) return  end)
   __has(self, "trace",   nil, function(self) return  end)

   __method(self, "__init", function(self, message, level)
      self.message = message
      self.level   = level
   end)
   __method(self, "__tostring", function(self)
       return tostring(__op_typeof(self).__name)..": "..tostring(self.trace)
   end)
   __method(self, "__throw", function(self, level) 
      level = level or 1
      self.info  = debug.getinfo(self.level + 1, "Sln")
      self.trace = debug.traceback(tostring(self.message), self.level + level)
   end)
end)

__class(__env,"SyntaxError",{Error},{},function(__env,self) end)
__class(__env,"AccessError",{Error},{},function(__env,self) end)
__class(__env,"ImportError",{Error},{},function(__env,self) end)
__class(__env,"ExportError",{Error},{},function(__env,self) end)
__class(__env,"TypeError",  {Error},{},function(__env,self) end)

Fiber = Type("Fiber")
Fiber.__index = Fiber
Fiber.__apply = function(class, body, ...)
   local self = setmetatable({ }, class) 
   self._coro = coroutine.create(body)
   self._args = { ... }
   return self
end
Fiber.new = function(class, ...)
   return class(...)
end
Fiber.ready = function(self)
   Scheduler:add_ready(self)
end
Fiber.suspend = function(self)
   Scheduler:del_ready(self)
end
Fiber.resume = function(self, ...)
   self._args = { ... }
   assert(coroutine.resume(self._coro, unpack(self._args)))
end
Fiber.status = function(self)
   return coroutine.status(self._coro)
end

Scheduler = Type("Scheduler")
do
   local self = Scheduler
   self.ready = setmetatable({ }, { __mode = "kv" })
   self.queue = { }
   self.loop  = __system.uv_default_loop()
   self.idle  = ffi.new('uv_idle_t')

   local on_idle_close = function() end
   function self:start()
      __system.uv_idle_init(self.loop, self.idle)
      __system.uv_idle_start(self.idle, function(handle, status)
         local fiber
         repeat
            fiber = table.remove(self.queue, 1)
         until #self.queue == 0 or self.ready[fiber]
         if fiber then
            self.ready[fiber] = nil
            self.current = fiber
            fiber:resume()
            self.current = nil
         else
            self:stop()
         end
      end)
      __system.uv_run(self.loop)
   end

   function self:stop()
      __system.uv_close(ffi.cast('uv_handle_t *', self.idle), on_idle_close)
   end

   function self:add_ready(fiber)
      if self.ready[fiber] then
         return true
      end
      self.ready[fiber] = true
      self.queue[#self.queue + 1] = fiber
   end

   function self:del_ready(fiber)
      self.ready[fiber] = nil
   end
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

LUPA_PATH = "./?.lu;./lib/?.lu;./src/?.lu"
do
   package.loaders[#package.loaders + 1] = function(modname)
      local Compiler = require('lupa.compiler').Compiler
      local filename = modname:gsub("%.", "/")
      for path in LUPA_PATH:gmatch("([^;]+)") do
         if path ~= "" then
            local filepath = path:gsub("?", filename)
            local file = io.open(filepath, "r")
            if file then
               local src = file:read("*a")
               return function(...)
                  local args = Array(...)
                  local good, retv = pcall(function()
                     local lua  = Compiler:compile(src)
                     local main = assert(loadstring(lua, '='..filepath))
                     local env  = setmetatable({ }, { __index = __env })
                     env.ARGV = args
                     env.FILE = filepath
                     return main(env)
                  end)
                  if not good then
                     error(__env.ImportError(
                        "failed to load "..tostring(modname)..": "..tostring(retv)), 2)
                  end
                  return retv
               end
            end
         end
      end
   end
end

function __op_yield(...)
   if Scheduler.current then
      Scheduler.current:ready()
   end
   return coroutine.yield(...)
end

local f1 = Fiber:new(function()
   for i=1, 10 do
      print("1 - tick: ", i)
      __op_yield()
   end
end)

local f2 = Fiber:new(function()
   for i=1, 10 do
      print("2 - tick: ", i)
      __op_yield()
   end
end)

f1:ready()
f2:ready()

Scheduler:start()

return __env
