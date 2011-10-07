module("kula.lang.ast", package.seeall)

local util   = require"kula.lang.util"
local string = _G.string
local table  = _G.table
local format = string.format
local concat = table.concat

local function class(class)
   class.__index = class
   class.__tostring = function(self)
      return util.dump(self)
   end
   setmetatable(class, {
      __call = function(_, self)
         if type(self) ~= "table" then self = { self } end
         return setmetatable(self, class)
      end;
   })
   class.render = function(self)
      error("NYI render:"..tostring(self))
   end
   return class
end

Code = class{ }
Code.render = function(self, ctx)
   return concat(self)
end

local binops = {
   ["=="] = "(%s)==(%s)";
   ["!="] = "(%s)~=(%s)";
   [">="] = "(%s)>=(%s)";
   ["<="] = "(%s)<=(%s)";
   ["<"] = "(%s)<(%s)";
   [">"] = "(%s)>(%s)";
   ["+"] = "(%s)+(%s)";
   ["-"] = "(%s)-(%s)";
   ["*"] = "(%s)*(%s)";
   ["/"] = "(%s)/(%s)";
   ["%"] = "(%s)%%(%s)";
   ["**"] = "(%s)^(%s)";
   ["&&"] = "(%s)and(%s)";
   ["||"] = "(%s)or(%s)";
   ["~"] = "(%s)..(%s)";
   ["=~"] = "Op.match(%s,%s)";
   ["!~"] = "not Op.match(%s,%s)";
   ['<<'] = "Op.lshift(%s,%s)";
   ['>>'] = "Op.rshift(%s,%s)";
   ['>>>'] = "Op.arshift(%s,%s)";
   ['|'] = "Op.bor(%s,%s)";
   ['&'] = "Op.band(%s,%s)";
   ['^'] = "Op.bxor(%s,%s)";
   ['in'] = "Op.contains(%s,%s)";
   ['as'] = "Op.as(%s,%s)";
   ['like'] = "Op.like(%s,%s)";
   ['with'] = "Op.with(%s,%s)";
}

local unrops = {
   ["!"] = "not(%s)";
   ["-"] = "-(%s)";
   ["#"] = "Op.size(%s)";
   ["~"] = "Op.bnot(%s)";
   ["typeof"] = 'Op.typeof(%s)';
}

local bassops = {
   ["+="] = "+";
   ["-="] = "-";
   ["*="] = "*";
   ["/="] = "/";
   ["%="] = "%";
   ["**="] = "**";
   ["~="] = "~";
   ["||="] = "||";
   ["&&="] = "&&";
   ["|="] = "|";
   ["&="] = "&";
   ["^="] = "^";
   [">>>="] = ">>>";
   [">>="] = ">>";
   ["<<="] = "<<";
}

Expr = class{ }
Expr.render = function(self, ctx, ...)
   return ctx:get(self[1], ...)
end

OpPrefix = class{ }
OpPrefix.render = function(self, ctx)
   local a = ctx:get(self[1])
   local f = unrops[self.oper]
   return format(f, a)
end

OpInfix = class{ }
OpInfix.render = function(self, ctx, rhs)
   if self.oper == '::' then
      self[2].base = self[1]
      local a, b = ctx:get(self[1]), ctx:get(self[2])
      if rhs then
         return format("%s.%s=%s", a, b, ctx:get(rhs))
      else
         return format("%s.%s", a, b)
      end
   elseif self.oper == '.' then
      self[2].base = self[1]
      local a, b = ctx:get(self[1]), ctx:get(self[2])
      if self.call then
         if self[1].tag == 'ident' and self[1][1] == 'super' then
            table.insert(self.call, 1, Id{ "self", pos = self[1].pos })
            return format("%s.%s(%s)", a, b, ctx:get(self.call))
         else
            if #self.call > 0 then
               return format("%s:%s(%s)", a, b, ctx:get(self.call))
            else
               return format("%s:%s()", a, b)
            end
         end
      else
         if rhs then
            return format("%s:__set_%s(%s)", a, b, ctx:get(rhs))
         else
            return format("%s:__get_%s()", a, b)
         end
      end
   elseif self.oper == "->" then
      if not self[2].head then
         self[2].head = FuncParams{ }
      end
      if #self[2].head == 0 then
         self[2].head[1] = Id{ '_', pos = self.pos }
      end
      self[1].call = List{ Function(self[2]) }
      self[2] = self[1].call
      self.oper = '('
      return OpPostCircumfix.render(self, ctx)
   else
      return format(binops[self.oper], ctx:get(self[1]), ctx:get(self[2]))
   end
end

OpPostCircumfix = class{ }
OpPostCircumfix.render = function(self, ctx, rhs)
   if self.oper == "[" then
      local a, b = ctx:get(self[1]), ctx:get(self[2])
      if rhs then
         return format("%s:__setitem(%s,%s)", a, b, ctx:get(rhs))
      else
         return format("%s:__getitem(%s)", a, b)
      end
   elseif self.oper == "::[" then
      local a, b = ctx:get(self[1]), ctx:get(self[2])
      if rhs then
         return format("%s[%s]=%s", a, b, ctx:get(rhs))
      else
         return format("%s[%s]", a, b)
      end
   elseif self.oper == "(" then
      if self[2] == nil then
         self[2] = List{ }
      end
      if not (self[1].tag == 'op_infix' and self[1].oper == '.') then
         if #self[2] > 0 then
            return format('%s(%s)', ctx:get(self[1]), ctx:get(self[2]))
         else
            return format('%s()', ctx:get(self[1]))
         end
      else
         self[1].call = self[2]
         return ctx:get(self[1])
      end
   end
end

OpTernary = class{ }
OpTernary.render = function(self, ctx)
   local t, a, b = ctx:get(self.test), ctx:get(self[1]), ctx:get(self[2])
   return format("%s and (%s) or (%s)", t, a, b)
end

OpCircumfix = class{ }
OpCircumfix.render = function(self, ctx)
   return format("(%s)", ctx:get(self[1]))
end

OpListfix = class{ }
OpListfix.render = function(self, ctx)
   local buf = { }
   for i=1, #self do
      buf[#buf + 1] = ctx:get(self[i])
   end
   return concat(buf, ',')
end

Bind = class{ }
Bind.render = function(self, ctx)
   if self.oper == '=' then
      local dest_list, expr_list = self[1], self[2]
      if #dest_list == 1 then
         local dest_expr = dest_list[1]
         if dest_expr[1].tag == 'ident' then
            local dest = ctx:get(dest_expr[1])
            local expr = ctx:get(expr_list[1] or Nil)
            ctx:fput("%s=%s", dest, expr)
         else
            ctx:put(ctx:get(dest_expr, expr_list[1] or Nil))
         end
         return
      end
      local tmp, rhs = List{ }, List{ }

      for i=1, #dest_list do
         tmp[#tmp + 1] = ctx:genid()
         if expr_list[i] then
            rhs[#rhs + 1] = ctx:get(expr_list[i])
         end
      end

      ctx:fput('local %s=%s;', ctx:get(tmp), ctx:get(rhs))

      for i=1, #dest_list do
         local dest_expr = dest_list[i]
         local temp = tmp[i]
         if dest_expr[1].tag == 'ident' then
            local dest = ctx:get(dest_expr,temp)
            ctx:fput("%s=%s", dest, temp)
         else
            ctx:put(ctx:get(dest_expr, temp))
         end
      end
   else
      if self[1].tag == 'ident' then
         local a, b = ctx:get(self[1]), ctx:get(self[2])
         local expr = format(binops[bassops[self.oper]], a, b)
         ctx:fput("%s=%s", a, expr)
      else
         ctx:put(ctx:get(self[1], self[2]))
      end
   end
end

VarDecl = class{ }
VarDecl.render = function(self, ctx)
   local lhs, rhs, grd = List{ }, List{ }, { }
   local var_list, expr_list = self[1], self[2] or List{ }
   for i=1, #var_list do
      lhs[#lhs + 1] = ctx:get(var_list[i])
      rhs[#rhs + 1] = expr_list[i] and ctx:get(expr_list[i])
   end

   local buf = { }
   if #rhs > 0 then
      buf[#buf + 1] = format('local %s=%s;', ctx:get(lhs), ctx:get(rhs))
   else
      buf[#buf + 1] = format('local %s;', ctx:get(lhs))
   end

   return concat(buf)
end

Id = class{ }
Id.render = function(self, ctx)
   if ctx.native_reserved[self[1]] then
      self[1] = ctx.native_reserved[self[1]]
   end
   if self.base then return self[1] end
   return self[1]
end
QName = class{ }
QName.render = function(self, ctx)
   local buf = { }
   for i=1, #self do
      buf[#buf + 1] = self[i][1]
   end
   return concat(buf, '.')
end
QName.to_list = function(self, ctx)
   local path = List{ }
   for i=1, #self do
      path[#path + 1] = String{ self[i][1] }
   end
   return path
end
QName.to_name = function(self, ctx)
   local buf = { }
   for i=1, #self do
      buf[#buf + 1] = self[i][1]
   end
   return concat(buf, '::')
end


List = class{ tag = 'List' }
List.render = function(self, ctx)
   local buf = { }
   for i=1, #self do
      buf[#buf + 1] = ctx:get(self[i])
   end
   return concat(buf, ',')
end

Call = class{ }
Call.render = function(self, ctx)
   local name, args = self[1], self[2]
   return format('%s(%s)', ctx:get(name), ctx:get(args))
end

Closure = class{ }
Closure.render = function(self, ctx)
   ctx:enter"function"
   for i=1, #self[1] do
      ctx:put(self[1][i])
      if i ~= #self[1] then ctx:put',' end
   end
   ctx:put')'
   for i=1, #self[2] do
      ctx:put(self[2][i])
   end
   ctx:put'end'
   return ctx:leave' '
end

Function = class{ }
Function.render = function(self, ctx)
   ctx:enter"function"
   ctx:fput('function(%s) %s %s end', Function.render_common(self, ctx))
   return ctx:leave()
end
Function.render_before = function(self, ctx)
   local buf = { }
   if self.head then
      for i=1, #self.head do
         local item = self.head[i]
         if item.tag == 'rest' then
            buf[#buf + 1] = format('local %s=Core.Tuple:new(...);', ctx:get(item[1]))
         end
      end
   end
   return concat(buf, ' ')
end
Function.render_common = function(self, ctx)
   local head = ''
   if self.head then
      head = ctx:get(self.head)
   end
   local before = Function.render_before(self, ctx)

   ctx:enter"code"
   for i=1, #self.body do
      local stmt = self.body[i]
      ctx:put(ctx:sync(stmt))
      if i==#self.body then
         if stmt.tag == 'expr' then
            stmt = Return{ List{ stmt } }
         elseif stmt.tag == 'expr_list' then
            stmt = Return{ stmt }
         end
      end
      ctx:put(stmt)
   end
   return head, before, ctx:leave()
end

FuncDecl = class{ }
FuncDecl.render = function(self, ctx)
   ctx:enter"function"
   local name = self.name
   if name.tag == 'ident' and ctx.scope.outer.tag ~= 'package' then
      ctx:fput('local function %s(%s) %s %s end', ctx:get(name), Function.render_common(self, ctx))
   else
      ctx:fput('function %s(%s) %s %s end', ctx:get(name), Function.render_common(self, ctx))
   end
   return ctx:leave()
end

VarList = class{ }
VarList.render = function(self, ctx)
   return ctx:get(List{ unpack(self) })
end

FuncParams = class{ }
FuncParams.render = function(self, ctx)
   local buf = { }
   for i=1, #self do
      local ident, code
      if self[i].tag == 'rest' then
         ident = self[i][1]
         code  = Code{ "..." }
      else
         ident = self[i]
         code  = ident
      end
      buf[#buf + 1] = ctx:get(code)
   end
   return concat(buf, ',')
end

Throw = class{ }
Throw.render = function(self, ctx)
   local trace = Table{ file = String{ctx.name}, pos = Number(self.pos) }
   return format('Op.throw(%s,%s)', ctx:get(self[1]), ctx:get(trace))
end

Yield = class{ }
Yield.render = function(self, ctx)
   return format('Op.yield(%s)', ctx:get(List{ unpack(self) }))
end

Try = class{ }
Try.render = function(self, ctx)
   local catch_node, finally_node

   local set_ret = ctx:genid()
   local num_ret = ctx:genid()

   ctx:enter"lambda".set_return = set_ret
   ctx:put'function() '
   for i=1, #self.body do
      ctx:put(self.body[i])
   end
   ctx:put'end'
   local try = ctx:leave()

   local catch
   if self.catch then
      self.catch.set_return = set_ret
      catch = ctx:get(self.catch)
   else
      catch = 'function() end'
   end

   local finally
   if self.finally then
      self.finally.set_return = set_ret
      finally = ctx:get(self.finally)
   else
      finally = 'function() end'
   end

   local ret_exp = Return{ List{ Code{ format('unpack(%s)', set_ret) } } }
   ctx:fput(
      "do local %s; xpcall(%s,%s); (%s)(); if %s then %s end end",
      set_ret, try, catch, finally, set_ret, ctx:get(ret_exp)
   )
end

Catch = class{ }
Catch.render = function(self, ctx)
   ctx:enter"lambda".set_return = self.set_return
   local head = ''
   if self.head then
      head = ctx:get(self.head)
   end
   ctx:fput('function(%s)', head)
   for i=1, #self[1] do
      ctx:put(self[1][i])
   end
   ctx:put'end'
   return ctx:leave()
end

Finally = class{ }
Finally.render = function(self, ctx)
   ctx:enter"lambda".set_return = self.set_return
   ctx:put'function()'
   for i=1, #self[1] do
      ctx:put(self[1][i])
   end
   ctx:put'end'
   return ctx:leave()
end

Nil = class{ }
Nil.render = function(self, ctx)
   return '(nil)'
end

True = class{ }
True.render = function(self, ctx)
   return '(true)'
end

False = class{ }
False.render = function(self, ctx)
   return '(false)'
end

Rest = class{ }
Rest.render = function(self, ctx)
   local name = ctx:get(self[1])
   return format('local %s=Core.Tuple:new(...)', name)
end

String = class{ }
String.render = function(self, ctx)
   if #self == 0 then
      self[#self + 1] = ""
   end
   if self.oper == '"""' then
      local buf = { }
      for i=1, #self do
         if self[i].tag == 'expr' then
            buf[#buf + 1] = format('tostring(%s)', ctx:get(self[i]))
         else
            buf[#buf + 1] = format('%q', self[1])
         end
      end
      return '('..concat(buf,'..')..')'
   elseif self.oper == '"' then
      local buf = { }
      for i=1, #self do
         if self[i].tag == 'expr' then
            buf[#buf + 1] = format('tostring(%s)', ctx:get(self[i]))
         else
            buf[#buf + 1] = format('"%s"', self[i])
         end
      end
      return '('..concat(buf,'..')..')'
   else
      return format('(%q)', self[1])
   end
end

Number = class{ }
Number.render = function(self, ctx)
   return '('..tostring(self[1]:gsub('_',''))..')'
end

Stmts = class{ }
Stmts.render = function(self, ctx)
   for i=1, #self do
      ctx:put(self[i])
   end
end

Array = class{ }
Array.render = function(self, ctx)
   return format("Core.Array:new(%s)", ctx:get(List{ unpack(self) }))
end

Hash = class{ }
Hash.render = function(self, ctx)
   return format("Core.Hash:new(%s)", ctx:get(Table{ unpack(self) }))
end

Pair = class{ }
Pair.render = function(self, ctx)
   if self[1].tag == "ident" then
      return format("[%q]=%s", ctx:get(self[1]), ctx:get(self[2]))
   else
      return format("[%s]=%s", ctx:get(self[1]), ctx:get(self[2]))
   end
end

Table = class{ }
Table.render = function(self, ctx)
   local seen = { }
   local buf = { }
   for i,v in ipairs(self) do
      seen[i] = true
      if getmetatable(v) == Pair then
         buf[#buf + 1] = ctx:get(v)
      else
         buf[#buf + 1] = "["..tostring(i).."]="..ctx:get(v)
      end
      buf[#buf + 1] = ','
   end
   for k,v in pairs(self) do
      if not seen[k] then
         if type(k) == 'string' then
            buf[#buf + 1] = format('[%q]=%s', k, ctx:get(v))
         else
            buf[#buf + 1] = format('[%s]=%s', ctx:get(k), ctx:get(v))
         end
         buf[#buf + 1] = ';'
      end
   end
   return '{'..concat(buf)..'}'
end

Tuple = class{ }
Tuple.render = function(self, ctx)
   local elems = List{ }
   for i=1, #self do
      elems[i] = ctx:get(self[i])
   end
   return format('Core.Tuple:new(%s)', ctx:get(elems))
end

Return = class{ }
Return.render = function(self, ctx)
   local list = self[1]
   local scope = ctx:find_scope"lambda"
   local buf = { }
   if scope and scope.set_return then
      buf[#buf + 1] = format(
         'do %s=Core.Tuple:new(%s); return %s end',
         scope.set_return, ctx:get(list), tostring(#list)
      )
   else
      buf[#buf + 1] = format("do return %s end", ctx:get(list))
   end
   return concat(buf)
end

If = class{ }
If.render = function(self, ctx)
   for i=1, #self, 2 do
      ctx:put(ctx:sync(self[i]))
      if i == #self and i % 2 == 1 then
         ctx:put'else'
         for j=1, #self[i] do
            ctx:put(self[i][j])
         end
      else
         if i==1 then
            ctx:put'if'
         else
            ctx:put'elseif'
         end
         ctx:fput('%s',ctx:get(self[i]))
         ctx:put'then'
         for j=1, #self[i + 1] do
            ctx:put(self[i + 1][j])
         end
      end
   end
   ctx:put'end'
end

For = class{ }
For.render = function(self, ctx)
   ctx:enter"loop"

   ctx:fput(
      "for %s=%s,%s",
      ctx:get(self.head[1]),
      ctx:get(self.head[2]),
      ctx:get(self.head[3])
   )

   if self.head[4] then
      ctx:put(","..ctx:get(self.head[4]))
   end
   ctx:put"do"

   ctx:enter"block"
   for i=1, #self.body do
      ctx:put(ctx:sync(self.body[i]))
      ctx:put(self.body[i])
   end
   local body = ctx:leave()

   if ctx.scope.stash.set_break then
      local brk = ctx.scope.stash.set_break
      ctx:fput('local %s; repeat %s until true if %s then break end', brk, body, brk)
   else
      ctx:fput('repeat %s until true', body)
   end

   ctx:put"end"
   ctx:put(ctx:leave())
end

ForIn = class{ }
ForIn.render = function(self, ctx)
   ctx:enter"loop"
   ctx:fput(
      "for %s in Op.each(%s) do",
      ctx:get(self.head.vars),
      ctx:get(self.head.iter)
   )

   ctx:enter"block"
   for i=1, #self.body do
      ctx:put(ctx:sync(self.body[i]))
      ctx:put(self.body[i])
   end
   local body = ctx:leave()

   if ctx.scope.stash.set_break then
      local brk = ctx.scope.stash.set_break
      ctx:fput('local %s; repeat %s until true if %s then break end', brk, body, brk)
   else
      ctx:fput('repeat %s until true', body)
   end
   ctx:put"end"
   ctx:put(ctx:leave())
end

While = class{ }
While.render = function(self, ctx)
   ctx:enter"loop"
   ctx:fput(
      'while %s do',
      ctx:get(self.head)
   )

   ctx:enter"block"
   for i=1, #self.body do
      ctx:put(ctx:sync(self.body[i]))
      ctx:put(self.body[i])
   end
   local body = ctx:leave()

   if ctx.scope.stash.set_break then
      local brk = ctx.scope.stash.set_break
      ctx:fput('local %s; repeat %s until true if %s then break end', brk, body, brk)
   else
      ctx:fput('repeat %s until true', body)
   end

   ctx:put"end"
   ctx:put(ctx:leave())
end

Block = class{ }
Block.render = function(self, ctx)
   ctx:enter"block"
   ctx:put"do"
   for i=1, #self do
      ctx:put(self[i])
   end
   ctx:put"end"
   ctx:put(ctx:leave())
end

Break = class{ }
Break.render = function(self, ctx)
   local brk = ctx:genid()
   ctx:find_scope"loop".stash.set_break = brk
   return format("do %s=true break end", brk)
end
Continue = class{ }
Continue.render = function(self, ctx)
   return "do break end"
end

NameList = class{ }
NameList.render = function(self, ctx)
   return ctx:get(List{ unpack(self) })
end

FromPath = class{ }
FromPath.render = function(self, ctx)
   if self[1].tag == 'ident' then
      local buf = { }
      for i=1, #self do
         local name = self[i]
         buf[#buf + 1] = format('%q', name[1])
      end
      return format('{%s}', concat(buf,','))
   else -- string
      return ctx:get(self[1])
   end
end

Import = class{ }
Import.render = function(self, ctx)
   local from = ctx:get(self.from)
   if self.name then -- import <name> from <path> [as <alias>|in <namespace>]
      local name = self.name
      if self.alias then
         local alias = self.alias
         ctx:fput('local %s=Core.import(%s,%q);', alias[1], from, name[1])
      elseif self.into then
         local into = ctx:get(self.into)
         ctx:fput('if not self.%s then %s={} end', into, into, into, into)
         ctx:fput('%s.%s=Core.import(%s,%q);', into, name[1], from, name[1])
      else
         ctx:fput('local %s=Core.import(%s,%q);', name[1], from, name[1])
      end
   elseif self.list then -- import <name_list> from <path>
      local list = self.list
      local lhs, rhs = List{ }, List{ }
      for i=1, #list do
         local name = list[i]
         lhs[#lhs + 1] = name[1]
         rhs[#rhs + 1] = format('%q', name[1])
      end
      ctx:fput('local %s=Core.import(%s,%s)', ctx:get(lhs), from, ctx:get(rhs))
   else -- import from <path>
      error('import from <path> is DEPRECATED')
   end
end

Unit = class{ }
Unit.render = function(self, ctx)
   ctx:enter"unit"
   Package.render_body(self, ctx)
   local body = ctx:leave()
   if self.tag == "unit" then
      return format('return require"kula.lang".unit(function(self,...) %s end,...);\n', body)
   else
      return body
   end
end

Package = class{ }
Package.render = function(self, ctx)
   local path = self.path:to_list(ctx)
   ctx:enter"package"
   self:render_body(ctx)
   local body = ctx:leave()
   return format('Core.package(self,{%s},function(self) %s end);', ctx:get(path), body)
end
Package.render_body = function(self, ctx)
   ctx:put(ctx:sync(self))
   for i=1, #self do
      local stmt = self[i]
      ctx:put(ctx:sync(stmt))
      local decl = stmt[1]
      if decl.tag:match('_decl$') then
         if decl.tag == 'var_decl' then
            ctx:put(decl)
         elseif decl.tag == 'package_decl' then
            ctx:put(decl)
         else
            if decl.tag == 'func_decl' then
               ctx:put(decl)
            else
               ctx:fput('%s=%s;', decl.name[1], ctx:get(decl))
            end
         end
      else
         ctx:put(decl)
      end
   end
end

Class = class{ }
Class.render = function(self, ctx)
   local name = self.name and self.name[1]
   local extends = 'nil'
   if self.extends then
      extends = ctx:get(self.extends[1])
   end

   ctx:enter"class"
   self:render_body(ctx, self[1], name)

   local body = ctx:leave()

   local with = ''
   if self.with then
      with = ctx:get(List{ unpack(self.with) })
   end

   return format('Core.class(%q,%s,function(self,super) %s end,{%s})', name, extends, body, with)
end
Class.render_body = function(self, ctx, body, name)
   local base = 'self'

   for i=1, #body do
      local decl = body[i]
      ctx:put(ctx:sync(decl))

      local meta = decl.meta or False
      if decl.tag == 'slot_decl' then
         local iden, expr = decl.name, decl[1] or Nil

         ctx:fput(
            'Core.has(%s,%q,function() return %s end,%s);',
            base, iden[1], ctx:get(expr), ctx:get(meta)
         )
      elseif decl.tag == 'meth_decl' then
         local expr = ctx:get(decl)
         ctx:fput('Core.method(%s,%q,%s,%s);', base, decl.name[1], expr, ctx:get(meta))
      elseif decl.tag == 'rule_decl' then
         local expr = ctx:get(decl)
         ctx:fput('Core.rule(%s,%q,%s,%s);', base, decl.name[1], expr, meta)
      elseif decl.tag == 'class_decl' or decl.tag == 'trait_decl' then
         local expr = ctx:get(decl)
         ctx:fput('%s.%s=%s;', base, decl.name[1], expr)
      else
         ctx:put(decl)
      end
   end
end

Trait = class{ }
Trait.render = function(self, ctx)
   local name = self.name and self.name[1]

   ctx:enter"trait"
   
   local params = '...'
   if self.params then
      params = ctx:get(self.params)
   end
   Class.render_body(self, ctx, self[1], name)

   local body = ctx:leave()

   local with = ''
   if self.with then
      with = ctx:get(List{ unpack(self.with) })
   end

   return format('Core.trait(%q,function(self,%s) %s end,{%s})', name, params, body, with)
end

Object = class{ }
Object.render = function(self, ctx)
   local name = self.name and self.name[1]
   local extends = 'nil'
   if self.extends then
      extends = ctx:get(self.extends[1])
   end

   ctx:enter"object"

   Class.render_body(self, ctx, self[1], name)

   local body = ctx:leave()

   local with = ''
   if self.with then
      with = ctx:get(List{ unpack(self.with) })
   end

   return format('Core.object(%q,%s,function(self,super) %s end,{%s})', name, extends, body, with)
end

Method = class{ }
Method.render = function(self, ctx)
   if not self.head then
      self.head = FuncParams{ }
   end
   if not (self.head[1] and self.head[1][1] == 'self') then
      table.insert(self.head, 1, Id{ 'self', pos = self.pos })
   end
   return Function.render(self, ctx)
end

Spread = class{ }
Spread.render = function(self, ctx)
   return format('Op.spread(%s)', ctx:get(self[1]))
end

Range = class{ }
Range.render = function(self, ctx)
   return format('Core.Range:new(%s,%s,%s)', ctx:get(self[1]), ctx:get(self[2]), ctx:get(self[3]))
end

Lambda = class{ }
Lambda.render = function(self, ctx)
   if not self.head then
      self.head = FuncParams{ }
   end
   if #self.head == 0 then
      self.head[#self.head + 1] = Id{ '_', pos = self.pos }
   end
   ctx:enter"function"
   if #self.body == 1 then
      if self.body[1].tag == 'expr' then
         self.body[1] = Return{ List{ self.body[1] } }
      elseif self.body[1].tag == 'expr_list' then
         self.body[1] = Return{ self.body[1] }
      end
   end
   ctx:fput('function(%s) %s %s end', Function.render_common(self, ctx))
   return ctx:leave()
end

Rule = class{ }
Rule.render = function(self, ctx)
   local name, body
   if self.tag == 'rule_decl' then
      name = self.name[1]
      body = self.body
   else
      name = ctx:genid"anon"
      body = self.body
   end
   return ctx:get(body)
end

Pattern = class{ }
Pattern.render = function(self, ctx)
   return format('Core.LPeg.P(%s)', ctx:get(self[1]))
end

RuleDecl = class{ }
RuleDecl.render = function(self, ctx)
   return 'local '..self.name[1]..'=Core.LPeg.P({'..ctx:get(self.body)..'})'
end

RuleBody = class{ }
RuleBody.render = function(self, ctx)
   return ctx:get(self[1])
end

RuleAlt = class{ }
RuleAlt.render = function(self, ctx)
   local a = ctx:get(self[1])
   local b = ctx:get(self[2])
   return a.."+"..b
end

RuleRange = class{ }
RuleRange.render = function(self, ctx)
   return 'Core.LPeg.R('..format('%q',self[1])..')'
end

RuleClass = class{ }
RuleClass.render = function(self, ctx)
   local buf = { }
   local neg = false
   for i=1, #self do
      if i==1 and self[i] == '^' then
         neg = true
      elseif type(self[i]) == 'table' then
         buf[#buf + 1] = ctx:get(self[i])
      else
         buf[#buf + 1] = 'Core.LPeg.P('..format('%q', self[i])..')'
      end
   end
   local pat = '('..concat(buf,"+")..')'
   if neg then
      return '(Core.LPeg.P(1)-'..pat..')'
   end
   return pat
end

RuleSeq = class{ }
RuleSeq.render = function(self, ctx)
   local buf = { }
   local pre = ''
   local i=1
   while i <= #self do
      if self[i] == '&' then
         pre = '#'
         i = i + 1
      elseif self[i] == '!' then
         i = i + 1
         pre = '-'
      else
         pre = ''
      end

      buf[#buf + 1] = pre..ctx:get(self[i])
      i = i + 1
   end
   return concat(buf,"*")
end

RuleProd = class{ }
RuleProd.render = function(self, ctx)
   local oper = self.oper
   local opnd
   if oper == '->' then
      return ctx:get(self[1])..'/'..ctx:get(self[2])
   elseif oper == '=>' then
      return 'Core.LPeg.Cmt('..ctx:get(self[1])..','..ctx:get(self[2])..')'
   elseif oper == '~>' then
      return 'Core.LPeg.Cf('..ctx:get(self[1])..','..ctx:get(self[2])..')'
   end
end

RuleRep = class{ }
RuleRep.render = function(self, ctx)
   local rep = self.oper
   if rep == '*' then
      return ctx:get(self[1])..'^0'
   elseif rep == '+' then
      return ctx:get(self[1])..'^1'
   elseif rep == '?' then
      return ctx:get(self[1])..'^-1'
   elseif rep == '^' then
      return ctx:get(self[1])..'^'..ctx:get(self[2])
   end
   return ctx:get(self[1])
end

RuleTerm = class{ }
RuleTerm.render = function(self, ctx)
   local str = ctx:get(self[1])
   return format('Core.LPeg.P(%s)',str)
end

RuleGroup = class{ }
RuleGroup.render = function(self, ctx)
   local buf = { }
   for i=1, #self do
      buf[#buf + 1] = ctx:get(self[i])
   end
   return '('..concat(buf, ' ')..')'
end

RuleGroupCapt = class{ }
RuleGroupCapt.render = function(self, ctx)
   if self.name then
      local name = self.name[1]
      return 'Core.LPeg.Cg('..ctx:get(self[1])..','..format('%q', name)..')'
   else
      return 'Core.LPeg.Cg('..ctx:get(self[1])..')'
   end
end

RuleBackCapt = class{ }
RuleBackCapt.render = function(self, ctx)
   return 'Core.LPeg.Cb('..format('%q', self[1][1])..')'
end

RulePredef = class{ }
RulePredef.render = function(self, ctx)
   return 'Core.LPeg.Def('..format('%q', self[1][1])..')'
end

RulePosCapt = class{ }
RulePosCapt.render = function(self, ctx)
   return 'Core.LPeg.Cp()'
end

RuleSubCapt = class{ }
RuleSubCapt.render = function(self, ctx)
   return 'Core.LPeg.Cs('..ctx:get(self[1])..')'
end

RuleConstCapt = class{ }
RuleConstCapt.render = function(self, ctx)
   return 'Core.LPeg.Cc('..ctx:get(self[1])..')'
end

RuleHashCapt = class{ }
RuleHashCapt.render = function(self, ctx)
   return 'Core.LPeg.Ch('..ctx:get(self[1])..')'
end

RuleArrayCapt = class{ }
RuleArrayCapt.render = function(self, ctx)
   return 'Core.LPeg.Ca('..ctx:get(self[1])..')'
end

RuleSimpleCapt = class{ }
RuleSimpleCapt.render = function(self, ctx)
   return 'Core.LPeg.C('..ctx:get(self[1])..')'
end

RuleAny = class{ }
RuleAny.render = function(self, ctx)
   return 'Core.LPeg.P(1)'
end

RuleRef = class{ }
RuleRef.render = function(self, ctx)
   if self[1].tag == 'ident' then
      return format('Core.LPeg.V(%q)', self[1][1])
   else
      return ctx:get(self[1])
   end
end



