module("kula.lang.parser", package.seeall)

local lpeg = require "lpeg"
local util = require "kula.lang.util"

---------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------

local function make_node(rule)
   local setmetatable = setmetatable
   return function(node)
      node.tag = rule.name
      if rule.node then
         return rule.node(node)
      end
      return setmetatable(node, ASTNode)
   end
end

function error_near(s, c)
   return (#s < c + 20) and
      string.sub(s, c) or
      string.sub(s, c, c + 20).."..."
end
function throw_error(subj, curr, mesg)
   local format = "ParseError: %s on line %s near '%s'"
   local near = error_near(subj, curr)
   if near == '' then near = '<EOF>' end
   local line = 1
   local index, limit = 1, curr
   while index <= limit do
      local s, e = subj:find("\n", index, true)
      if s == nil or e > limit then break end
      index = e + 1
      line = line + 1
   end
   error(string.format(format, mesg, line, near), 2)
end
local function syntax_error(mesg)
   return lpeg.Cmt(lpeg.Cp(), function(subj, curr)
      throw_error(subj, curr, mesg)
   end)
end

local locale = lpeg.locale();

---------------------------------------------------------------------------
-- ASTNode
---------------------------------------------------------------------------
ASTNode = { }
ASTNode.__index = ASTNode
ASTNode.__tostring = function(self)
   return util.dump(self)
end
ASTNode_meta = { }
ASTNode_meta.__call = function(class, self)
   if not self.tag then
      self.tag = table.remove(self, 1)
   end
   return setmetatable(self, class)
end
setmetatable(ASTNode, ASTNode_meta)

---------------------------------------------------------------------------
-- rules
---------------------------------------------------------------------------
Rule = { }
Rule.__index = Rule
Rule.__call = function(self, rule)
   self.patt = rule[1] or rule.patt
   self.node = rule[2] or rule.node
   return self
end
Rule.new = function(name)
   local self = { name = name }
   return setmetatable(self, Rule)
end
Rule.pattern = function(self)
   return self.patt
end

Match = { }
Match.__index = Match
Match.__call = function(self, rule)
   self.patt = rule[1]
   self.node = rule[2] or ASTNode
   return self
end
Match.new = function(name)
   local self = { name = name }
   return setmetatable(self, Match)
end
Match.pattern = function(self)
   return lpeg.Ct(lpeg.Cg(lpeg.Cp(),"pos") * self.patt) / make_node(self)
end

---------------------------------------------------------------------------
-- Parser
---------------------------------------------------------------------------
Parser = { }
Parser.__index = Parser
Parser.__call = function(self, name)
   return lpeg.V(name)
end
Parser.new = function()
   local self = { rules = { } }

   self.rules.space = locale.space
   self.rules.alpha = locale.alpha
   self.rules.alnum = locale.alnum
   self.rules.digit = locale.digit
   self.rules.xdigit = locale.xdigit

   self.rules.BOF = lpeg.P(function(s,i) return (i==1) and i end)
   self.rules.EOF = lpeg.P(-1)

   self.rules.NL = lpeg.P"\n"
   self.rules.WS = lpeg.V"NL" + locale.space

   self.rules.skip = self.rules.WS^0

   return setmetatable(self, Parser)
end
Parser.rule = function(self, name)
   local rule = Rule.new(name)
   self.rules[name] = rule
   return rule
end
Parser.skip = function(self, patt)
   if type(patt) == "table" then
      patt = assert(patt[1])
   end
   self.rules.skip = patt
end
Parser.match = function(self, name)
   local match = Match.new(name)
   self.rules[name] = match
   return match
end
Parser.grammar = function(self, gram)
   if gram then
      for name, patt in pairs(gram) do
         self.rules[name] = patt
      end
   end
   return self.rules
end
Parser.express = function(self, name)
   local expr = Express.new(name, self)
   self.rules[name] = expr
   return expr
end
Parser.parse = function(self, subject, ...)
   local gram = self.gram
   if not gram then
      gram = { }
      for name, rule in pairs(self.rules) do
         if type(rule) == "table" then
            gram[name] = rule:pattern(gram)
         else
            gram[name] = rule
         end
      end
      self.gram = gram
   end
   return lpeg.P(gram):match(subject, ...)
end
Parser.error = function(self, mesg)
   return syntax_error(mesg)
end
Parser.expect = function(self, token)
   return lpeg.P(token) + syntax_error("'"..token.."' expected")
end

---------------------------------------------------------------------------
-- expressions
---------------------------------------------------------------------------
Express = { }
Express.__index = Express
Express.new = function(name, parser)
   local self = {
      name = name;
      node = ASTNode;
      parser = parser;
      op_table = { }
   }
   return setmetatable(self, Express)
end
Express.make = function(self, node)
   self.node = node
   return self
end
Express.clone = function(self, name)
   local copy = {
      name = name;
      node = self.node;
      prim = self.prim;
      parser = self.parser;
      op_table = { unpack(self.op_table) };
   }
   self.parser.rules[name] = copy
   return setmetatable(copy, Express)
end
Express.primary = function(self, prim)
   self.prim = prim
   return self
end
local IDGEN = 0
Express.pattern = function(self, gram)
   local op_table = self.op_table
   table.sort(op_table, function(a,b)
      if a._prec == b._prec then
         if type(a) == "string" and type(b) == "string" then
            return #a.oper > #b.oper
         end
      end
      return a._prec > b._prec
   end)
   local expr = lpeg.V(self.name)
   local prev = lpeg.V(self.prim)
   local name, patt, op, prevop
   for i=1, #op_table do
      op = op_table[i]
      name = op._name
      if not name then
         IDGEN = IDGEN + 1
         name = tostring(IDGEN)
      end
      patt = op:pattern(prev, expr)
      gram[name] = patt
      prev = lpeg.V(name)
   end
   return lpeg.Ct(lpeg.Cg(lpeg.Cp(), "pos") * prev) / make_node(self)
end
Express.op_listfix = function(self, oper)
   local op = OpListfix.new(oper)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_infix = function(self, oper, ...)
   local op = OpInfix.new(oper, ...)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_prefix = function(self, oper, ...)
   local op = OpPrefix.new(oper, ...)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_postfix = function(self, oper)
   local op = OpPostfix.new(oper)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_circumfix = function(self, oper)
   local op = OpCircumfix.new(oper)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_postcircumfix = function(self, oper)
   local op = OpPostCircumfix.new(oper)
   self.op_table[#self.op_table + 1] = op
   return op
end
Express.op_ternary = function(self, oper)
   local op = OpTernary.new(oper)
   self.op_table[#self.op_table + 1] = op
   return op
end

local function make_op_rule(class, oper, ...)
   if select('#', ...) == 0 then
      local self = { oper = oper }
      return setmetatable(self, class)
   else
      local name = { oper }
      local patt
      if oper:match"^%w+$" then
         patt = lpeg.P(oper) * #(1 - (locale.alnum + lpeg.P"_"))
      else
         patt = lpeg.P(oper)
      end
      local list = { ... }
      for i=1, #list do
         local oper = list[i]
         name[#name + 1] = oper
         if oper:match"^%w+$" then
            oper = lpeg.P(oper) * #(1 - (locale.alnum + lpeg.P"_"))
         end
         patt = patt + oper
      end
      local self = { oper = patt, name = table.concat(name, " "), node = ASTNode }
      return setmetatable(self, class)
   end
end

OpListfix = { name = "OpListfix" }
OpListfix.__index = OpListfix
OpListfix.new = function(oper)
   local self = { oper = oper, node = ASTNode }
   return setmetatable(self, OpListfix)
end
OpListfix.make = function(self, node)
   self.node = node
end
OpListfix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpListfix.pattern = function(self, term)
   local ws = lpeg.V"skip"
   return (lpeg.Cg(term) * (ws * self.oper * ws * lpeg.Cg(term))^1) / self:handler()
      + term
end
OpListfix.handler = function(self)
   return function(...)
      return self.node { tag = "op_listfix", ... }
   end
end

OpInfix = { name = "OpInfix" }
OpInfix.__index = OpInfix
OpInfix.new = function(oper, ...)
   return make_op_rule(OpInfix, oper, ...)
end
OpInfix.make = function(self, node)
   self.node = node
end
OpInfix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpInfix.expr = function(self, expr)
   self._expr = expr
   return self
end
OpInfix.key = function(self, name)
   self._name = name
   return self
end
OpInfix.pattern = function(self, term)
   local ws = lpeg.V"skip"
   local oper, expr
   if self.oper:match"^%w+$" then
      oper = lpeg.C(self.oper) * #(1 - locale.alnum)
   else
      oper = lpeg.C(self.oper)
   end
   if self._expr then
      expr = lpeg.V(self._expr)
   else
      expr = term
   end
   return lpeg.Cf(
      lpeg.Cg(term) *
      lpeg.Cg(ws * oper * ws * expr)^0,
      self:handler()
   )
end
OpInfix.handler = function(self)
   return function(l, o, r)
      return self.node { tag = "op_infix", oper = o, l, r }
   end
end

OpPrefix = { name = "OpPrefix" }
OpPrefix.__index = OpPrefix
OpPrefix.new = function(oper, ...)
   return make_op_rule(OpPrefix, oper, ...)
end
OpPrefix.make = function(self, node)
   self.node = node
end
OpPrefix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpPrefix.pattern = function(self, term)
   local ws = lpeg.V"skip"
   local oper
   if self.oper:match"^%w+$" then
      oper = lpeg.C(self.oper) * #(1 - (locale.alnum + lpeg.P"_"))
   else
      oper = lpeg.C(self.oper)
   end
   return lpeg.Cf(
      oper * ws * lpeg.Cg(term),
      self:handler()
   ) + term
end
OpPrefix.handler = function(self)
   return function(o, r)
      return self.node { tag = "op_prefix", oper = o; r }
   end
end

OpPostfix = { name = "OpPostfix" }
OpPostfix.__index = OpPostfix
OpPostfix.new = function(oper, ...)
   return make_op_rule(OpPostfix, oper, ...)
end
OpPostfix.make = function(self, node)
   self.node = node
end
OpPostfix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpPostfix.pattern = function(self, term, expr)
   local ws = lpeg.V"skip"
   return lpeg.Cf(
      lpeg.Cg(term) * ws * lpeg.C(self.oper),
      self:handler()
   ) + term
end
OpPostfix.handler = function(self)
   return function(l, o)
      return self.node { tag = "op_postfix", oper = o; l }
   end
end

OpCircumfix = { name = "OpCircumfix" }
OpCircumfix.__index = OpCircumfix
OpCircumfix.new = function(oper)
   local start = string.sub(oper, 1, 1)
   local close = string.sub(oper, 2, 2)
   local self = {
      oper  = oper,
      node  = ASTNode,
      start = start,
      close = lpeg.P(close) + syntax_error("'"..close.."' expected")
   }
   return setmetatable(self, OpCircumfix)
end
OpCircumfix.make = function(self, node)
   self.node = node
end
OpCircumfix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpCircumfix.list = function(self, oper)
   self._list = oper
   return self
end
OpCircumfix.expr = function(self, expr)
   self._expr = expr
   return self
end
OpCircumfix.pattern = function(self, term, expr)
   local ws = lpeg.V"skip"
   if self._expr then
      expr = lpeg.P(self._expr)
   end
   if self._list then
      expr = expr * lpeg.Cg(ws * lpeg.P(self._list) * ws * expr)^0
   end
   return lpeg.Cf(
      lpeg.Cg(self.start) * ws * lpeg.Cg(expr^-1) * ws * self.close,
      self:handler()
   ) + term
end
OpCircumfix.handler = function(self)
   return function(s, t)
      return self.node { tag = "op_circumfix", oper = s; t }
   end
end

OpPostCircumfix = { name = "OpPostCircumfix" }
OpPostCircumfix.__index = OpPostCircumfix
OpPostCircumfix.new = function(oper)
   local start, close
   if type(oper) == "string" then
      start = string.sub(oper, 1, 1)
      close = string.sub(oper, 2, 2)
      oper  = start
   else
      start = oper[1]
      close = oper[2]
      oper  = oper[3]
   end
   local self = {
      oper  = oper,
      node  = ASTNode,
      start = start,
      close = lpeg.P(close) + syntax_error("'"..close.."' expected")
   }
   return setmetatable(self, OpPostCircumfix)
end
OpPostCircumfix.make = function(self, node)
   self.node = node
end
OpPostCircumfix.prec = function(self, prec)
   self._prec = prec
   return self
end
OpPostCircumfix.expr = function(self, expr)
   self._expr = expr
   return self
end
OpPostCircumfix.key = function(self, name)
   self._name = name
   return self
end
OpPostCircumfix.pattern = function(self, term, expr)
   local ws = lpeg.V"skip"
   if self._expr then
      expr = lpeg.V(self._expr)
   end
   return lpeg.Cf(
      lpeg.Cg(term) *
      lpeg.Cg(ws * lpeg.Cc(self.oper) * self.start * ws * lpeg.Cg(expr^-1) * ws * self.close)^0
   , self:handler())
end
OpPostCircumfix.handler = function(self)
   return function(l, s, e, ...)
      return self.node { tag = "op_postcircumfix", oper = s; l, e, ... }
   end
end

OpTernary = { name = "OpTernary" }
OpTernary.__index = OpTernary
OpTernary.new = function(oper)
   local start = string.sub(oper, 1, 1)
   local close = string.sub(oper, 2, 2)
   local self = {
      oper  = oper,
      node  = ASTNode,
      start = start,
      close = lpeg.P(close) + syntax_error("'"..close.."' expected")
   }
   return setmetatable(self, OpTernary)
end
OpTernary.make = function(self, node)
   self.node = node
end
OpTernary.prec = function(self, prec)
   self._prec = prec
   return self
end
OpTernary.pattern = function(self, term, expr)
   local ws = lpeg.V"skip"
   return lpeg.Cf(
      lpeg.Cg(term) * lpeg.Cg(
         ws * self.start * ws * term *
         ws * self.close * ws * term
      )^0,
      self:handler()
   )
end
OpTernary.handler = function(self)
   return function(l, t, f)
      return self.node { tag = "op_ternary", test = l; t, f }
   end
end

