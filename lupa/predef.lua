local __env = setmetatable({ }, { __index = _G })
setfenv(1, __env)
package.cpath = ';;./lib/?.so;'..package.cpath

local bit = require("bit")
local ffi = require('ffi')

do
   local uvh = io.open('./include/uv.h')
   local def = uvh:read('*a')
   uvh:close()
   ffi.cdef(def)
   _system = assert(ffi.load('./lib/libuv.so'))
end
local uv = assert(ffi.load('./lib/libuv.so'))
local loop = uv.uv_loop_new()

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
   return tostring(name):gsub('(_%w%w)', function(o)
      if demangles[o] then
         return demangles[o]
      else
         return o
      end
   end)
end

local metamethods = {
   __tostring = function(a) return a:toString() end;
   __concat = function(a, b) return a:_ti(b) end;
   __call = function(self, ...) return self:apply(...) end;
   __add = function(a, b) return a:_pl(b) end;
   __sub = function(a, b) return a:_mi(b) end;
   __pow = function(a, b) return a:_st_st(b) end;
   __mod = function(a, b) return a:_pe(b) end;
   __div = function(a, b) return a:_sl(b) end;
   __mul = function(a, b) return a:_st(b) end;
   __unm = function(a) return a:_mi_() end;
   __len = function(a) return a:_po_() end;
   __eq = function(a, b) return a:_eq(b) end;
   __ne = function(a, b) return a:_ba_eq(b) end;
   __gt = function(a, b) return a:_gt(b) end;
   __ge = function(a, b) return a:_gt_eq(b) end;
   __lt = function(a, b) return a:_lt(b) end;
   __le = function(a, b) return a:_lt_eq(b) end;
}

__env[mangle"::"] = function(self, name)
   return self[name]
end
function _package(into,name,body)
   local curr = into
   local path = { }
   for n in name:gmatch'([%w_]+)' do
      path[#path + 1] = n
      if rawget(curr, '__dict') == nil then
         rawset(curr, '__dict', { })
      end
      local e = setmetatable({ }, { __index = into })
      local p = setmetatable({
         __dict = e;
         __name = n;
         __path = { unpack(path) };
         __body = function() end;
      }, Package)
      curr.__dict[n] = p
      if curr == into then
         into[n] = p
      end
      curr = p
   end
   curr.__body = body
   body(curr.__dict, curr)
   return curr
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
   class.__need = { }

   class.__rules = setmetatable(rules, { __index = from.__rules })
   class.__slots = setmetatable(slots, { __index = from.__slots })
   class.__index = slots

   for k,v in pairs(metamethods) do
      class[k] = v
   end

   class.new = function(self, ...)
      local obj = setmetatable({ }, self)
      obj:init(...)
      return obj
   end
   setmetatable(class, Class)

   local outer = into
   local inner = setmetatable({ }, { __index = outer })

   inner[name] = class
   class[mangle"::"] = function(self, name)
      return class.__slots[name] or inner[name]
   end

   if with then
      for i=1,#with do
         with[i]:make(inner, class)
      end
   end

   body(inner, class, from)
   for k,v in pairs(class.__need) do
      if class.__slots[k] == nil then
         error("ComposeError: '"..tostring(k).."' is needed", 2)
      end
   end
   return class
end

function trait(into, name, with, want, body)
   local trait = { }
   trait.__want = want
   trait.__name = name
   trait.__body = body
   trait.__with = with
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

function has(into, key, type, ctor) 
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
   into.__slots[key] = get
   into.__slots[key..'_eq'] = set
end

function method(into, name, code) 
   into.__slots[name] = code
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
         return __op_as(tab, Table)
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
         return __op_as(tab, Array)
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
   if next(what, nil) == nil then
      from, what[1] = from:match('^(.-)%.([%w_]+)$')
   end
   local mod = __load(from)
   if what[1] == '*' then
      for key, val in pairs(mod) do
         into[key] = val
      end
   else
      for sym,key in pairs(what) do
         local val = rawget(mod, key)
         if val == nil then
            __op_throw( ImportError("'"..tostring(key).."' from '"..tostring(from).."' is nil", 2) )
         end
         into[sym] = val
      end
   end
   return mod
end

function import(into, from, what, dest) 
   local mod = __load(from)
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
               __op_throw( ImportError("'"..tostring(key).."' from '"..tostring(from).."' is nil", 2) )
            end
            into[key] = val
         end
      end
   else
      return mod
   end
end


function export(...)
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
   local __throw = mt and mt.__throw
   if __throw then
      __throw(err, 2)
   end
   return error(err, 2)
end

function __op_in(key, obj)
   local mt = getmetatable(obj)
   return obj[key] ~= nil
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

Type = { }
Type.__name = "Type"
Type.__call = function(self, ...)
   return self:apply(...)
end
Type.isa = function(self, that)
   if that == Any then
      return true
   end
   local meta = getmetatable(self)
   return meta == that
end
Type.can = function(self, key)
   local meta = getmetatable(self)
   if type(self) == 'table' then
      return rawget(self, key) ~= nil or (meta and rawget(meta, key) ~= nil)
   else
      return meta and rawget(meta, key) ~= nil
   end
end
Type.does = function(self, that)
   return false
end
Type.__index = Type
Type.apply = function(self, name)
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

Guard = Type()
Guard.__index = Guard
Guard.of = function(self, ...)
   local narg = select('#',...)
   if self.__want == narg then
      return guard(self.__name, self.__want - narg, self.__body, ...)
   else
      error("ComposeError: want "..tostring(self.__want).." arguments (got "..tostring(narg)..")", 2)
   end
end

function guard(name, want, body, ...)
   local guard = setmetatable({
      __name = name;
      __want = want;
      __body = body;
   }, Guard)
   if want == 0 then
      body(guard, ...)
   else
      function guard:coerce() error("TypeError: coerce to abstract guard", 2) end
   end
   return guard
end

Method = Type("Method")
Method.__index = Method
Method.__tostring = function(self)
   return "<Method: "..tostring(self.__name)..">"
end
Method.of = function(self, ...)
   local narg = select('#',...)
   return Method(self.__name, self.__want - narg, self.__code(...))
end
Method.__call = function(self, ...)
   if self.__want == 0 then
      return self.__code(...)
   end
   error("TypeError: parameterize method "..self.__name.." - want "..tostring(self.__want), 2)
end
Method.apply = function(type, name, code, want)
   local self = setmetatable({ }, type)
   self.__name = name
   self.__code = code
   self.__want = want or 0
   return self
end

Rule = Type("Rule")
Rule.__index = Rule
Rule.apply = function(type, into, name, patt)
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
         if _patt.type(v) == "pattern" then
            grmr[k] = v
         end
      end
      grmr[1] = key
      rule = _patt.P(grmr)
      rawset(obj, self, rule)
   end
   return rule
end

Package = Type("Package")
Package.__tostring = function(self)
   return table.concat(self.__path, '::')
end
Package.__index = { }
Package.__index[mangle"::"] = function(self, name)
   return self.__dict[name]
end


Class = { }
Class.__tostring = function(self) 
   return "<class "..tostring(self.__name)..">"
end
Class.__index = function(obj, key)
   return obj.__slots[key]
end
Class.__call = function(self,...)
   return self:apply(...)
end

Any = Type("Any")
Any.__from = { }
Any.__with = { }
Any.__size = 0
Any.__slots = Any
Any.__index = Any
Any.init = function(self, ...)
   local spec = ... or Table{ }
   for k,v in pairs(spec) do
      self[k..'_eq'](self, v)
   end
end
Any.coerce = function(self, that)
   if that:isa(self) then
      return that
   else
      error("TypeError: "..tostring(that).." is not a "..name, 2)
   end
end
Any.toString = function(self)
   local meta = getmetatable(self)
   debug.setmetatable(self, nil)
   local addr = tostring(self):match('^%w+: (.+)$')
   debug.setmetatable(self, meta)
   return '<object '..meta.__name..'@'..addr..'>'
end
Any.isa = function(self, that)
   if that == Any then
      return true
   end
   local meta = getmetatable(self)
   if meta == Class then
      meta = self
   end
   return meta == that or (meta.__from and (meta.__from == that))
end
Any.can = function(self, key)
   local meta = getmetatable(self)
   if meta == Class then
      meta = self
   end 
   return rawget(meta, key) ~= nil
end
Any.does = function(self, that)
   return self.__with[that.__body] ~= nil
end

Trait = Type()
Trait.__tostring = function(self) 
   return "trait "..self.__name
end
Trait.__index = Trait
Trait.of = function(self, ...)
   local args = Array(...)
   local copy = trait(nil, self.__name .. tostring(...), self.__with, self.__want, self.__body)
   local make = self.make
   copy.make = function(self, into, recv) 
      return make(self, into, recv, __op_spread(args))
   end
   return copy
end
Trait.make = function(self, into, recv, ...) 
   for i = 1, #self.__with, 1 do
      self.__with[i]:make(into, recv)
   end
   self.__body(into, recv, ...)
   recv.__with[self.__body] = true
   return into
end
Trait.coerce = function(self, that)
   if that.__with[self.__body] == nil then
      error("TypeError: "..tostring(that).." does not compose "..tostring(self), 2)
   end
   return that
end

Array = Type("Array")
Array.apply = function(self, ...)
   return setmetatable({ ... }, self)
end
Array.of = function(self, type)
   local A = Array()
   A.__slots = { }
   A.__index = A.__slots
   A.__slots[mangle'_[]='] = function(a,k,v)
      a[k]=type:coerce(v)
   end
   A.coerce = function(self, v)
      local get, set = mangle'_[]', mangle'_[]='
      for i=1, v:len() do
         v[set](v,i,v[get](v,i))
      end
      return setmetatable(v, A)
   end
   return A
end
Array.__slots = { }
Array.__index = Array.__slots
Array.__slots.len = function(self) return #self end
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
   local out = Array()
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
   local out = Array()
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
Array.__slots.reverse = function(self) 
   local out = Array()
   for i=1, #self do
      out[i] = self[#self - i + 1]
   end
   return out
end

Table = Type("Table")
Table.__index = Table
Table.len = function(self) return #self end
Table.apply = function(self, table)
   return setmetatable(table or { }, self)
end
Table.each = function(self)
   return pairs
end
Table.__tostring = function(self)
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
Table[mangle"_[]"] = rawget
Table[mangle"_[]="] = rawset
Table.__each = pairs
Table.of = function(self, ...)
   local T = Table{ }
   local ktype, vtype
   if select('#', ...) == 1 then
      vtype = ...
      T[mangle'_[]='] = function(t, k, v)
         t[k] = vtype:coerce(v)
      end
   elseif select('#', ...) == 2 then
      ktype, vtype = ...
      T[mangle'_[]='] = function(t, k, v)
         t[ktype:coerce(k)] = vtype:coerce(v)
      end
   else
      error("of takes 1 or 2 parameters", 2)
   end
   T.__index = T
   T.coerce = function(self, val)
      local set = mangle'_[]='
      for k,v in _each(val) do
         val[set](val,k,v)
      end
      return setmetatable(val, T)
   end
   return T
end

for k,v in pairs(table) do Table[k] = v end

Range = Type("Range")
Range.__index = Range
Range.apply = function(self, min, max, inc) 
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
Void.coerce = function(self, ...)
   if select("#", ...) ~= 0 then
      __op_throw(TypeError("value in Void", 2))
   end 
   return ...
end

Nil = Type("Nil")
Nil.__index = function(self, key)
   local val = Type[key]
   if val == nil then
      __op_throw("TypeError: no such member '"..demangle(key).."' in type Nil", 2)
   end
   return val
end
debug.setmetatable(nil, Nil)

None = Type("None")

Number = Type("Number")
Number.__index = Number
Number.times = function(self, block)
   for i=1, self do
      block(i)
   end
end
Number.coerce = function(self, val) 
   local v = tonumber(val)
   if v == nil then
      __op_throw(TypeError("cannot coerce '"..tostring(val).."' to Number", 2))
   end
   return v
end
Number._mi_ = function(a) return -a end
Number._st = function(a, b) return a * b end
Number._pe = function(a, b) return a % b end
Number._sl = function(a, b) return a / b end
Number._lt = function(a, b) return a < b end
Number._gt = function(a, b) return a > b end
Number._pl = function(a, b) return a + b end
Number._mi = function(a, b) return a - b end
Number._ba = function(a) return not a end
Number._st_st = function(a, b) return a ^ b end
Number._gt_eq = function(a, b) return a >= b end
Number._lt_eq = function(a, b) return a <= b end
Number._eq_eq = function(a, b) return a == b end
Number._ba_eq = function(a, b) return a ~= b end
debug.setmetatable(0, Number)

String = Type("String")
for k,v in pairs(string) do
   String[k] = v
end
String._eq_eq = function(a, b) return a == b end
String._pl    = function(a, b) return a .. tostring(b) end
String.__index = String
String.coerce = function(self, val)
   return tostring(val)
end
String.__match = function(a, p)
   return _patt.P(p):match(a)
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
String.len = function(self)
   return #self
end
debug.setmetatable("", String)

Boolean = Type("Boolean")
Boolean.__index = Boolean;
debug.setmetatable(true, Boolean)

Function= Type("Function")
Function.__index = Function
Function.coerce = function(self, code, ...)
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

Pattern = setmetatable(getmetatable(_patt.P(1)), Type)
Pattern.__call = function(patt, self, subj, ...)
   return patt:match(subj, ...)
end
Pattern.__index[mangle"~~"] = function(patt, subj)
   return patt:match(subj)
end
_patt.meta = Pattern

Error = class(__env, "Error", nil, {}, function(__env,self)
   has(self, "level",   nil, function(self) return 1 end)
   has(self, "message", nil, function(self) return "unknown" end)
   has(self, "info",    nil, function(self) return {} end)
   has(self, "trace",   nil, function(self) return "" end)

   method(self,'apply',function(self,...)
      return self:new(...)
   end)
   method(self,'init',function(self,message,level)
      self:message_eq(demangle(message))
      self:level_eq(level)
   end)
   method(self,'toString',function(self)
      return tostring(__op_typeof(self).__name)..": "..tostring(self:trace())
   end)
   method(self,'__throw',function(self,level)
      level = level or 1
      self:trace_eq(demangle(debug.traceback(self:message(), self:level() + level)))
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

Fiber = Type("Fiber")
Fiber.__index = Fiber
Fiber.apply = function(class, body, ...)
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
   self.loop  = _system.uv_default_loop()
   self.idle  = ffi.new('uv_idle_t')

   local on_idle_close = function() end
   function self:start()
      _system.uv_idle_init(self.loop, self.idle)
      _system.uv_idle_start(self.idle, function(handle, status)
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
      _system.uv_run(self.loop)
   end

   function self:stop()
      _system.uv_close(ffi.cast('uv_handle_t *', self.idle), on_idle_close)
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

__env.global = _G
return __env

