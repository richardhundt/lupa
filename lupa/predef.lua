local __env = setmetatable({ }, { __index = _G })
setfenv(1, __env)
package.cpath = ';;./lib/?.so;'..package.cpath

local bit = require("bit")
local ffi = require('ffi')

function newtable(...) return { ... } end
local rawget, rawset = rawget, rawset

local mangles = {
   ["["] = "_lb",
   ["]"] = "_rb",
   ["$"] = "_do",
   ["_"] = "_us",
   ["~"] = "_ti",
   ["@"] = "_at",
   ["#"] = "_po",
   ["*"] = "_st",
   ["/"] = "_sl",
   ["%"] = "_pe",
   ["+"] = "_pl",
   ["-"] = "_mi",
   [":"] = "_co",
   ["!"] = "_ba",
   ["?"] = "_qm",
   ["="] = "_eq",
   [">"] = "_gt",
   ["<"] = "_lt",
   ["&"] = "_am",
   ["^"] = "_ca",
   ["|"] = "_pi",
   ["."] = "_dt",
}

local demangles = { }
for k,v in pairs(mangles) do
   demangles[v] = k
end

local function mangle(name)
   return name:gsub('(%W)', function(o)
      return mangles[o]
   end)
end
function demangle(name)
   return String(name):gsub('(_%w%w)', function(o)
      if demangles[o] then
         return demangles[o]
      else
         return o
      end
   end)
end

local Meta = {
   __call = function(self, ...) return self:apply(...) end;
   __tostring = function(self) return self:toString() end;
}

__env[mangle"::"] = function(self, name)
   return self[name]
end

local function newenviron(outer)
   return setmetatable({ }, { __index = outer })
end
local function newindexer(slots)
   return function(self, key)
      local val = slots[key]
      if val == nil then
         error("TypeError: no such member '"..tostring(key).."' in "..tostring(self), 2)
      end
      return val
   end
end

function class(into, name, from, with, body)
   if from == nil then
      from = Any
   end

   local class = { }
   local slots = { }
   local rules = { }

   class.__name = name
   class.__from = from
   class.__size = from.__size
   class.__with = { }
   class.__need = { }

   class.__rules = setmetatable(rules, { __index = from.__rules })
   class.__slots = setmetatable(slots, { __index = from.__slots })
   class.__index = newindexer(slots)

   for k,v in pairs(Meta) do
      class[k] = v
   end

   class.new = function(self, ...)
      local obj = setmetatable({ }, self)
      if self.__slots.init then
         self.__slots.init(obj, ...)
      end
      return obj
   end
   setmetatable(class, Class)

   local inner = newenviron(into)

   inner[name] = class
   class[mangle"::"] = function(self, name)
      return class.__slots[name] or inner[name]
   end

   if with then
      for i=1,#with do
         with[i]:make(inner, class)
      end
   end

   body(inner, class, from.__slots)
   for k,v in pairs(class.__need) do
      if class.__slots[k] == nil then
         error("ComposeError: '"..tostring(k).."' is needed", 2)
      end
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
function needs(into, name)
   into.__need[name] = true
end

function object(into, name, from, with, body)
   if from ~= nil then
      if getmetatable(from[i]) ~= Class then
         from = getmetatable(from)
      end
   end
   local anon = class(into, "#"..name, from, with, body)
   local inst = setmetatable({ }, anon)
   return inst
end

function has(into, key, type, ctor, meta) 
   into.__size = into.__size + 1
   local idx = into.__size
   local function set(obj, val)
      if type then
         rawset(obj, idx, type:coerce(val))
      else
         rawset(obj, idx, val)
      end
   end
   local function get(obj)
      local val = rawget(obj, idx)
      if val == nil then
         val = ctor(obj)
         set(obj, val)
      end
      return val
   end
   if meta then
      into[key] = get
      into[key..'_eq'] = set
   else
      into.__slots[key] = get
      into.__slots[key..'_eq'] = set
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
   local get = function(obj)
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
         if __match(er, type) then
             return body(er)
         end
      end
      error(er, 2)
   end
end

_patt = require("lpeg")
_patt.setmaxstack(1024)
do
   local function make_capt_hash(init)
       return function(tab)
         if init ~= nil then
            for k,v in _each(init) do
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

   local predef = { }

   predef.nl  = _patt.P("\n")
   predef.pos = _patt.Cp()

   local any=_patt.P(1)
   _patt.locale(predef)

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

   _patt.predef = predef
   _patt.Def = function(id)
      if predef[id] == nil then
         error("No predefined pattern '"..tostring(id).."'", 2)
      end
      return predef[id]
   end
end

function import(into, from, what) 
   local mod = __load(from)
   if next(what, nil) == nil then
      local path = { }
      for frag in from:gmatch'([^%.]+)' do
         path[#path + 1] = frag
      end
      into[path[#path]] = mod
   else
      for sym,key in pairs(what) do
         local val = rawget(mod, key)
         if val == nil then
            throw( ImportError:new("'"..tostring(key).."' from '"..tostring(from).."' is nil", 2) )
         end
         into[sym] = val
      end
   end
   return mod
end

function import(into, from, what, dest) 
   local mod = __load(from)
   local path = { }
   for frag in from:gmatch"([^%.]+)" do
      path[#path + 1] = frag
   end
   if what then
      if dest then
         into[dest] = { }
         into = into[dest]
         into[mangle'::'] = function(self, name) return self[name] end
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
               throw( ImportError:new("'"..tostring(key).."' from '"..tostring(from).."' is nil", 2) )
            end
            into[key] = val
         end
      end
   else
      return mod
   end
end

function export(from, ...)
   local what = Array:new(...)
   local exporter = { }
   for i = 1, #what do
      local expt = what[i];
      local key, val = expt[1], expt[2]
      if val == nil then
         throw("ExportError: '"..tostring(key).."' is nil", 2)
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
   if a:is(b) then
      return true
   end
   return false
 end

__op_as     = setmetatable
typeof = getmetatable
__op_yield  = coroutine["yield"]

function throw(err)
   local throw = err.throw
   if throw then
      throw(err, 2)
   end
   return error(err, 2)
end
__op_throw = throw

function _in(key, obj)
   local mt = getmetatable(obj)
   local _in = mt and mt.__in
   if _in then
      return _in(obj,key)
   end
   return obj[key] ~= nil
end
__op_in = _in

function __op_like(this, that)
   for k,v in pairs(that) do
      if type(this[k]) ~= type(v) then
         return false
      end
      if not this[k]:is(getmetatable(v)) then
         return false
      end
   end
   return true
end

function _each(a, ...)
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

Any = setmetatable({ }, Meta)
Any.coerce = function(self, ...) return ...  end
Any.__name = "Any"
Any.__from = { }
Any.__with = { }
Any.__size = 0
Any.__slots = { }
Any.__index = newindexer(Any.__slots)
Any.__slots._ba_eq = function(a, b) return a ~= b end
Any.__slots._eq_eq = function(a, b) return a == b end
Any.__slots.coerce = function(self, that)
   if that:is(self) then
      return that
   else
      error("TypeError: "..tostring(that).." is not a "..tostring(self), 2)
   end
end
Any.__slots.apply = function(self)
   error(tostring(self).." "..type(self).." is not callable", 2)
end
Any.__slots.init = function(self, ...)
   local spec = ... or Table:new{ }
   for k,v in pairs(spec) do
      self[k..'_eq'](self, v)
   end
end
Any.__slots.toString = function(self)
   return '<object '..tostring(getmetatable(self).__name)..'>'
end
Any.__slots.is = function(self, that)
   if that == Any then return true end
   local meta = getmetatable(self)
   return meta == that or (meta.__from and (meta.__from == that))
end
Any.__slots.can = function(self, key)
   return getmetatable(self).__slots[key] ~= nil
end
Any.__slots.does = function(self, that)
   return getmetatable(self).__with[that.__body] ~= nil
end

Type = { }
Type.__name  = "Type"
Type.new = function(class, name)
   local type = { }
   type.__name = name
   type.__from = Any
   type.__with = { }
   type.__size = 0
   type.__slots = setmetatable({ }, { __index = Any.__slots })
   type.__index = newindexer(type.__slots)
   type.toString = function() return '<type '..name..'>' end
   for k,v in pairs(Meta) do type[k] = v end
   return setmetatable(type, class)
end
Type.__slots = setmetatable({ }, { __index = Any.__slots })
Type.__index = newindexer(Type.__slots)
for k,v in pairs(Meta) do Type[k] = v end

local function newtype(name)
   return Type:new(name)
end

Class = newtype"Class"
Class.__slots[mangle"::"] = function(obj, key)
   return obj.__slots[key]
end
Class.__slots.toString = function(self) 
   return "<class "..tostring(self.__name)..">"
end

Trait = newtype"Trait"
Trait.__slots.toString = function(self)
   return "<trait "..tostring(self.__name)..">"
end
Trait.__slots.coerce = function(self, ...)
   if that.__with[self.__body] == nil then
      error("TypeError: "..tostring(that).." does not compose "..tostring(self), 2)
   end
   return that
end
Trait.__slots.of = function(self, ...)
   local args = { ... }
   local want = self.__want - #args
   if want ~= 0 then
      error("TypeError: trait "..tostring(self.__name).." takes "..tostring(self.__want).." parameters but got "..tostring(#args), 2)
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
      error("TypeError: trait "..tostring(self.__name).." takes "..tostring(self.__want).." parameters", 2)
   end
   for i = 1, #self.__with, 1 do
      self.__with[i]:make(into, recv)
   end
   self.__body(into, recv, ...)
   recv.__with[self.__body] = true
   return into
end

Array = newtype"Array"
Array.new = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.apply = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.coerce = function(self, that)
   if not that:is(self) then
      error("TypeError: not an array", 2)
   end
   return that
end
Array.__index = Array.__slots
Array.__slots.len = function(self)
   return #self
end
Array.__slots.toString = function(self)
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
Array.__slots[mangle'_[]'] = rawget
Array.__slots[mangle'_[]='] = rawset
Array.__slots.unpack = unpack
Array.__slots.insert = table.insert
Array.__slots.remove = table.remove
Array.__slots.concat = table.concat
Array.__slots.sort = table.sort
Array.__slots.each = function(self, block)
   for i=1, #self do
      block(self[i])
   end
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
   local v = self[#self]
   self[#self] = nil
   return v
end
Array.__slots.shift = function(self)
   local v = self[1]
   for i=2, #self do
      self[i - 1] = self[i]
   end
   self[#self] = nil
   return v
end
Array.__slots.unshift = function(self, v)
   for i=#self+1, 1, -1 do
      self[i] = self[i-1]
   end
   self[1] = v
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

Table = newtype"Array"
Table.new = function(self, table)
   return setmetatable(table or { }, self)
end
Table.apply = function(self, ...)
   return self:new(...)
end
Table.__index = Table.__slots
Table.__slots.toString = function(self)
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
Table.__each = pairs
Table.__slots.len = function(self) return #self end
Table.__slots.each = function(self)
   return pairs(self)
end
Table.__slots[mangle"_[]"] = rawget
Table.__slots[mangle"_[]="] = rawset

for k,v in pairs(table) do Table.__slots[k] = v end

Range = newtype"Range"
Range.apply = function(self, min, max, inc) 
   min = assert(tonumber(min), "range min is not a number")
   max = assert(tonumber(max), "range max is not a number")
   inc = assert(tonumber(inc or 1), "range inc is not a number")
   return setmetatable({ min, max, inc }, self)
end
Range.__slots.iter = function(self)
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
Range.__slots.each = function(self, block)
   for i in Range.__slots.iter(self) do
      block(i)
   end
end

Void = newtype"Void"
Void.apply = function(self, ...)
   if select("#", ...) ~= 0 then
      throw(TypeError:new("value in Void", 2))
   end 
   return ...
end

Nil = newtype"Nil"
Nil.__tostring = nil
Nil.__slots.apply = function(self)
   error("TypeError: attempt to call a nil value", 2)
end
Nil.__slots.coerce = function(self, val)
   if val == nil then return val end
   error("TypeError: attempt to coerce "..tostring(val).." to nil", 2)
end
debug.setmetatable(nil, Nil)

Number = newtype"Number"
Number.apply = function(self, val) 
   local v = tonumber(val)
   if v == nil then
      throw(TypeError:new("cannot coerce '"..tostring(val).."' to Number", 2))
   end
   return v
end
Number.coerce = Number.apply
Number[mangle">"] = function(self, val)
   return function(v)
      if not v:_gt(val) then
         error("Constraint Number > "..tostring(val).." failed for "..tostring(v), 2)
      end
      return v
   end
end
Number.__tostring = nil
Number.__slots.toString = tostring
Number.__slots.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
Number.__slots._mi_us = function(a) return -a end
Number.__slots._st = function(a, b) return a * b end
Number.__slots._pe = function(a, b) return a % b end
Number.__slots._sl = function(a, b) return a / b end
Number.__slots._pl = function(a, b) return a + b end
Number.__slots._mi = function(a, b) return a - b end
Number.__slots._ba = function(a) return not a end
Number.__slots._st_st = function(a, b) return a ^ b end
Number.__slots._gt = function(a, b) return a > b end
Number.__slots._lt = function(a, b) return a < b end
Number.__slots._gt_eq = function(a, b) return a >= b end
Number.__slots._lt_eq = function(a, b) return a <= b end
Number.__slots._ba_eq = function(a, b) return a ~= b end
Number.__slots._eq_eq = function(a, b) return a == b end
debug.setmetatable(0, Number)

String = newtype"String"
String.__tostring = nil
String.apply = function(self, val)
   return tostring(val)
end
String.coerce = function(self, that)
   return tostring(that)
end
for k,v in pairs(string) do
   String.__slots[k] = v
end
String.__slots.toString = function(self) return self end
String.__slots._pl = function(a, b) return a .. tostring(b) end
String.__slots._gt = function(a, b) return a > b end
String.__slots._lt = function(a, b) return a < b end
String.__slots._gt_eq = function(a, b) return a >= b end
String.__slots._lt_eq = function(a, b) return a <= b end
String.__slots._ba_eq = function(a, b) return a ~= b end
String.__slots._eq_eq = function(a, b) return a == b end
String.__slots[mangle"~~"] = function(a, p)
   return _patt.P(p):match(a)
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
Boolean.coerce = function(v)
   return not(not(v))
end
Boolean.__slots.toString = function(self) return tostring(self) end
debug.setmetatable(true, Boolean)

Function = newtype"Function"
Function.__call = nil
Function.__tostring = nil
Function.__slots.coerce = function(self, ...)
   return self(...)
end
Function.coerce = function(self, that)
   if type(that) ~= 'function' then
      error("TypeError: cannot coerce "..tostring(that).." to Function", 2)
   end
   return that
end
Function.__slots.toString = function(self) return tostring(self) end
debug.setmetatable(function() end, Function)

Thread = newtype"Thread"
Thread.__tostring = nil
Thread.yield = coroutine.yield
Thread.wrap  = coroutine.wrap
Thread.coerce = function(self, code)
   if type(code) ~= "function" then
      error("TypeError: cannot coerce "..tostring(code).." to Thread", 2)
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

Pattern = setmetatable(getmetatable(_patt.P(1)), Type)
Pattern.__name = "Pattern"
Pattern.__from = Any
Pattern.__with = { }
Pattern.__slots = setmetatable(Pattern.__index, { __index = Any.__slots })
Pattern.__index = newindexer(Pattern.__slots)
Pattern.toString = function() return '<type '..name..'>' end
for k,v in pairs(Meta) do
   Pattern[k] = v
end
Pattern.__slots.apply = function(patt, self, subj, ...)
   return patt:match(subj, ...)
end
Pattern.__slots[mangle"~~"] = function(patt, subj)
   return patt:match(subj)
end

Error = class(__env, "Error", nil, {}, function(__env,self)
   has(self, "level",   nil, function(self) return 1 end)
   has(self, "message", nil, function(self) return "unknown" end)
   has(self, "info",    nil, function(self) return {} end)
   has(self, "trace",   nil, function(self) return "" end)

   method(self,'init',function(self,message,level)
      self:message_eq(demangle(message))
      self:level_eq(level)
   end)
   method(self,'toString',function(self)
      return tostring(typeof(self).__name)..": "..tostring(self:trace())
   end)
   method(self,'throw',function(self,level)
      level = level or 1
      self:trace_eq(demangle(debug.traceback(self:message(), self:level() + level)))
      error(self)
   end)
end)

SyntaxError = class(__env,"SyntaxError",Error,{},function() end)
AccessError = class(__env,"AccessError",Error,{},function() end)
ImportError = class(__env,"ImportError",Error,{},function() end)
ExportError = class(__env,"ExportError",Error,{},function() end)
TypeError   = class(__env,"TypeError",  Error,{},function() end)

function evaluate(lua)
   local main = assert(loadstring(lua))
   local fenv = setmetatable({ }, { __index = __env })
   fenv.self = fenv
   setfenv(main, fenv)
   return xpcall(main, function(err,...)
      print(debug.traceback(demangle(err), 3))
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

__env.global = _G
__env.main = __env
return __env

