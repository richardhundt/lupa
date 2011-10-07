module("kula.lang.grammar", package.seeall)

local lpeg   = require "lpeg"
local parser = require "kula.lang.parser"
lpeg.setmaxstack(500)

local ast = require"kula.lang.ast"

local m = lpeg
local p = parser.Parser.new()
local s = m.V"skip"
local semicolon = (s * m.P";")^-1
local line_comment = m.P"//" * (1 - m.V"NL")^0 * m.V"NL"
local span_comment = m.P"/*" * ((m.V"NL" + 1) - m.P"*/")^0 * m.P"*/"
local comment = line_comment + span_comment
local idsafe = -(m.V"alnum" + m.P"_")

p:skip { (comment + m.V"WS")^0 }

p:rule(1) {
   m.V"BOF" * s * m.V"unit" * s * (m.V"EOF" + p:error"parse error")
}
p:match"unit" {
   m.V"unit_body_stmt" * (s * m.V"unit_body_stmt")^0;
   ast.Unit;
}
p:match"unit_body_stmt" {
   m.V"package_decl"
   + m.V"import_stmt"
   + m.V"var_decl"
   + m.V"func_decl"
   --[[ XXX: lookahead + error handling for these
   + m.V"slot_decl"
   + m.V"rule_decl"
   + m.V"meth_decl"
   --]]
   + m.V"class_decl"
   + m.V"trait_decl"
   + m.V"object_decl"
   + #m.V"return_stmt" * p:error"return outside of function body"
   + m.V"statement";
}
p:rule"statement" {
     m.V"block_stmt"
   + m.V"if_stmt"
   + m.V"for_stmt"
   + m.V"for_in_stmt"
   + m.V"while_stmt"
   + m.V"return_stmt"
   + m.V"bind_stmt"
   + m.V"throw_stmt"
   + m.V"yield_stmt"
   + m.V"try_catch"
   + m.V"break_stmt"
   + m.V"continue_stmt"
   --+ m.V"assert_stmt"
   + m.V"expr_stmt"
   + s * m.P";";
}
p:match"statements" {
   m.V"statement" * (s * m.V"statement")^0;
   ast.Stmts;
}
p:rule"keyword" {
   (
      m.P"var" + "function" + "class" + "is" + "with" + "like" --+ "assert"
      + "nil" + "true" + "false" + "typeof" + "return" + "in" + "for" + "throw"
      + "delete" + "extends" + "as" + "method" + "has" + "from"
      + "break" + "continue" + "package" + "import" + "try" + "catch"
      + "finally" + "if" + "else" + "yield"
   ) * idsafe
}

p:match"ident" {
   (m.C((m.V"alpha" + "_") * (m.V"alnum" + "_")^0) - m.V"keyword");
   ast.Id;
}
p:match"qname" {
   m.V"ident" * ("::" * m.V"ident")^0;
   ast.QName;
}
p:rule"hexadec" {
   m.C(m.P"-"^-1 * s * "0x" * m.V"xdigit"^1)
}
p:rule"decimal" {
   m.C(
      m.P"-"^-1 * s * (m.V"digit" * m.P'_'^-1)^1
      * (m.P"." * (m.V"digit" * m.P'_'^-1)^1)^-1
      * (m.S"eE" * m.P"-"^-1 * (m.V"digit" * m.P'_'^-1)^1)^-1
   )
}
p:match"number" {
   m.V"hexadec" + m.V"decimal";
   ast.Number;
}
p:match"string" {
   m.Cg(m.C'"""', "oper") * (m.V"string_expr" + m.C(
      (m.P'\\\\' + m.P'\\"' + m.P'\\%' + (1 - (m.P'"""' + m.V"string_expr")))^1
   ))^0 * p:expect'"""'
   + m.Cg(m.C'"', "oper") * (m.V"string_expr" + m.C(
      (m.P'\\\\' + m.P'\\"' + m.P'\\%' + (1 - (m.P'"' + m.V"string_expr")))^1
   ))^0 * p:expect'"'
   + m.Cg(m.C"'", "oper") * m.C((m.P"\\\\" + m.P"\\'" + (1 -m.P"'"))^0) * p:expect"'"
   + m.Cg(m.C"'''", "oper") * m.C((m.P"\\\\" + m.P"\\'" + (1 -m.P"'''"))^0) * p:expect"'''";
   ast.String;
}
p:rule"string_expr" {
   m.P"${" * s * m.V"expr" * s * m.P"}"
}
p:rule"primary" {
     m.V"ident"
   + m.V"range"
   + m.V"number"
   + m.V"string"
   + m.V"nil"
   + m.V"spread"
   + m.V"true"
   + m.V"false"
   + m.V"array_literal"
   + m.V"hash_literal"
   + m.V"pattern_literal"
   + m.V"lambda_expr"
   + m.V"tuple_literal"
   + m.V"func_literal"
   + m.Cg(m.C"(" * s * m.V"expr" * s * p:expect")" / function(o, a, ...)
      return ast.OpCircumfix{ tag = 'op_circumfix', pos = a.pos, oper = o, a, ... }
   end)
}
p:rule"term" {
   m.Cf(m.Cg(m.V"primary")
   * m.Cg(s * m.V"tail_expr")^0, function(a, o, b, ...)
      if o == '.' or o == '::' or o == 'as' or o == '->' then
         return ast.OpInfix{ tag = 'op_infix', pos = a.pos, oper = o, a, b }
      elseif o then
         return ast.OpPostCircumfix{ tag = 'op_postcircumfix', pos = a.pos, oper = o, a, b, ... }
      else
         return a
      end
   end)
}
p:rule"tail_expr" {
   m.C"[" * s * m.V"expr" * s * p:expect"]"
   + m.C"." * s * m.V"ident"
   + m.P"::" * s * m.P"[" * m.Cc"::[" * s * m.V"expr" * s * p:expect"]"
   + m.C"::" * s * m.V"ident"
   + m.C"as" * idsafe * s * m.V"expr"
   + m.C"(" * s * m.V"expr_list"^-1 * s * p:expect")"
   + m.C"->" * s * m.Ct(m.V"func_common")
}
p:match"nil"    { m.P"nil"   * idsafe; ast.Nil   }
p:match"true"   { m.P"true"  * idsafe; ast.True  }
p:match"false"  { m.P"false" * idsafe; ast.False }
p:match"rest"   { m.P"..."   * m.V"ident"; ast.Rest }
p:match"spread" { m.P"..."   * m.V"expr"; ast.Spread }

p:match"var_decl" {
   m.P"var" * idsafe * s
   * m.V"var_list" * (s * m.P"=" * s * m.V"expr_list" * semicolon)^-1;
   ast.VarDecl;
}
p:match"var_list" {
   m.V"ident" * (s * "," * s * m.V"ident")^0;
   ast.VarList;
}
p:match"expr_list" {
   (m.V"expr" * (s * "," * s * m.V"expr")^0);
   ast.List;
}
p:match"term_list" {
   (m.V"term" * (s * "," * s * m.V"term")^0);
   ast.List;
}
p:rule"expr_stmt" {
   m.V"expr" / function(node)
      --[[
      if node[1].oper == nil then
         local format = "SyntaxError: %s on line %s - %s"
         error(string.format(format, "bare term", node.pos.line, tostring(node)))
      end
      --]]
      return ast.Expr(node)
   end * semicolon
}
p:match"block" {
   m.P"{" * s * m.V"block_body"^-1 * s * p:expect"}";
   ast.Block;
}
p:rule"block_body" {
   m.V"block_body_stmt" * (s * m.V"block_body_stmt")^0
}
p:rule"block_body_stmt" {
   m.V"func_decl"
   + m.V"var_decl"
   + m.V"statement"
}
p:match"block_stmt" {
   m.P"{" * s * m.V"block_body" * s * p:expect"}";
   ast.Block;
}
p:match"for_stmt" {
   m.P"for" * idsafe * s
   * m.Cg(m.V"for_head", "head") * s
   * m.Cg(m.V"block", "body");
   ast.For;
}
p:match"for_head" {
   m.V"ident" * s * "=" * s * m.V"expr" * s
   * p:expect"," * s * m.V"expr" * (s * "," * s * m.V"expr")^-1;
}
p:match"for_in_stmt" {
   m.P"for" * idsafe * s
   * m.Cg(m.V"for_in_head", "head") * s
   * m.Cg(m.V"block", "body");
   ast.ForIn;
}
p:match"for_in_head" {
   m.Cg(m.V"var_list", "vars") * s
   * m.P"in" * idsafe * s
   * m.Cg(m.V"list_expr_noin", "iter") * s
}
p:match"while_stmt" {
   m.P"while" * idsafe * s
   * m.Cg(m.V"expr", "head") * s
   * m.Cg(m.V"block", "body");
   ast.While;
}
p:match"if_stmt" {
   m.P"if" * idsafe * s * m.V"expr" * s * m.V"block" * s
   * (m.P"else" * idsafe * s * m.P"if" * idsafe * s * m.V"expr" * s * m.V"block" * s)^0
   * (m.P"else" * idsafe * s * m.V"block")^-1;
   ast.If
}
p:match"yield_stmt" {
   m.P"yield" * idsafe * s * m.V"expr_list";
   ast.Yield;
}
p:match"throw_stmt" {
   m.P"throw" * idsafe * s * m.V"expr";
   ast.Throw;
}
p:match"try_catch" {
   m.P"try" * idsafe * s * m.Cg(m.V"block", "body")
   * (s * m.Cg(m.V"catch_block", "catch"))^-1
   * (s * m.Cg(m.V"finally_block", "finally"))^-1;
   ast.Try;
}
p:match"catch_block" {
   m.P"catch" * idsafe * s
   * p:expect"(" * s * m.Cg(m.V"ident", "head")^-1 * s * p:expect")" * s * m.V"block";
   ast.Catch;
}
p:match"finally_block" {
   m.P"finally" * idsafe * s * m.V"block";
   ast.Finally;
}
p:match"break_stmt" {
   m.P"break" * idsafe;
   ast.Break;
}
p:match"continue_stmt" {
   m.P"continue" * idsafe;
   ast.Continue;
}
p:match"array_literal" {
   m.P"[" * s * m.V"items"^-1 * s * p:expect"]";
   ast.Array;
}
p:rule"items" {
   m.V"expr" * (s * "," * s * m.V"expr")^0 * (s * ",")^-1
}

p:match"tuple_literal" {
   m.P"(" * s * (
      m.V"expr" * (s * "," * s * m.V"expr")^1 * (s * ",")^-1
      + m.V"expr" * s * ","
      + m.P","
   ) * s * p:expect")";
   ast.Tuple;
}

p:match"hash_literal" {
   m.P"{" * s * m.V"pairs"^-1 * s * p:expect"}";
   ast.Hash;
}
p:rule"pairs" {
   m.V"pair" * (s * "," * s * m.V"pair")^0 * (s * ",")^-1
}
p:match"pair" {
   (m.V"ident" + m.P"[" * s * m.V"expr" * s * p:expect"]") * s
   * p:expect"=" * s * m.V"expr";
   ast.Pair;
}

p:match"lambda_expr" {
   m.P"->" * s * m.V"func_common";
   ast.Lambda;
}

p:match"range" {
   m.P"[" * m.V"expr" * ":" * m.V"expr" * (":" * m.V"expr")^-1 * p:expect"]";
   ast.Range;
}
p:match"func_decl" {
   m.P"function" * idsafe * s
   * m.Cg(m.V"qname", "name") * s * m.V"func_common";
   ast.FuncDecl;
}
p:match"meth_decl" {
   m.Cg(m.P"meta" * idsafe * s * m.Cc(ast.True), "meta")^-1
   * m.P"method" * idsafe * s
   * m.Cg(m.V"ident", "name") * s
   * m.V"func_common";
   ast.Method;
}
p:match"func_literal" {
   m.P"function" * idsafe * s * m.V"func_common";
   ast.Function;
}
p:rule"func_common" {
   (
      m.P"(" * s
      * m.Cg((m.V"func_params" * s + p:error"invalid parameter list"), "head")
      * p:expect")" * s
   )^-1
   * m.Cg(m.V"block", "body")
}
p:match"func_params" {
   ((m.V"ident" * (s * "," * s * m.V"ident")^0)^-1
   * (s * "," * s * m.V"rest")^-1) * (s * m.V"rest")^-1
   + m.P(true);
   ast.FuncParams;
}
p:match"return_stmt" {
   m.P"return" * idsafe * s * m.V"expr_list"^-1;
   ast.Return;
}
p:match"class_decl" {
   m.P"class" * idsafe * s * m.Cg(m.V"ident", "name") * s
   * m.Cg(m.V"class_extends", "extends")^-1 * s
   * m.Cg(m.V"class_with", "with")^-1 * s
   * m.V"class_body";
   ast.Class;
}
p:match"object_decl" {
   m.P"object" * idsafe * s * m.Cg(m.V"ident", "name") * s
   * m.Cg(m.V"class_extends", "extends")^-1 * s
   * m.Cg(m.V"class_with", "with")^-1 * s
   * m.V"class_body";
   ast.Object;
}

p:match"class_extends" {
   m.P"extends" * idsafe * s * m.V"qname"
}
p:match"class_with" {
   m.P"with" * idsafe * s * m.V"expr"
   * (s * m.P"with" * idsafe * s * m.V"expr")^0
}
p:match"class_body" {
   p:expect"{" * s
   * (m.V"class_body_stmt" * (s * m.V"class_body_stmt")^0)^-1 * s
   * p:expect"}";
   ast.Block;
}
p:rule"class_body_stmt" {
   m.V"class_body_decl"
   + #m.V"return_stmt" * p:error"return outside of function body"
   + m.V"statement"
}
p:rule"class_body_decl" {
     m.V"var_decl"
   + m.V"slot_decl"
   + m.V"rule_decl"
   + m.V"meth_decl"
   + m.V"func_decl"
   + m.V"class_decl"
   + m.V"trait_decl"
   + m.V"object_decl";
}
p:match"slot_decl" {
   m.Cg(m.P"meta" * idsafe * s * m.Cc(ast.True), "meta")^-1
   * m.P"has" * idsafe * s
   * m.Cg(m.V"ident", "name")
   * (s * m.P"=" * s * m.V"expr" * semicolon)^-1;
}

p:match"trait_decl" {
   m.P"trait" * idsafe * s * m.Cg(m.V"ident", "name") * s
   * (m.P"(" * s * m.Cg(m.V"func_params", "params")^-1 * s * p:expect")")^-1 * s
   * m.Cg(m.V"class_with", "with")^-1 * s
   * m.V"class_body";
   ast.Trait;
}


------------------------------------------------------------------------------
-- binding
------------------------------------------------------------------------------
p:rule"bind_stmt" {
     m.V"bind_expr"
   + m.V"bind_binop_expr"
}
p:match"bind_expr" {
   m.V"expr_list" * s * m.Cg(m.C"=", "oper") * s * m.V"expr_list" * s * semicolon;
   ast.Bind;
}
p:match"bind_binop_expr" {
   m.V"expr" * s * m.Cg(m.C(
      m.P"+=" + "-=" + "**=" + "*=" + "/=" + "%="
      + "||=" + "|=" + "&=" + "&&=" + "^=" + "~="
      + ">>>=" + ">>=" + "<<="
   ), "oper") * s * m.V"expr" * semicolon;
   ast.Bind;
}

------------------------------------------------------------------------------
-- packages/import
------------------------------------------------------------------------------
p:match"package_decl" {
   m.P"package" * s * m.Cg(m.V"qname", "path") * s
   * p:expect"{"
   * (s * m.V"package_body_stmt")^0 * s
   * p:expect"}";
   ast.Package;
}
p:match"package_body_stmt" {
   m.V"package_decl"
   + m.V"import_stmt"
   + m.V"var_decl"
   + m.V"func_decl"
   --[[ XXX: lookahead + error handling for these
   + m.V"slot_decl"
   + m.V"rule_decl"
   + m.V"meth_decl"
   --]]
   + m.V"class_decl"
   + m.V"trait_decl"
   + m.V"object_decl"
   + #m.V"return_stmt" * p:error"return outside of function body"
   + m.V"statement";
}

p:match"from_path" {
   m.V"ident" * ("::" * m.V"ident")^0 + m.V"string";
   ast.FromPath;
}
p:match"name_list" {
   m.V"ident" * (s * "," * s * m.V"ident")^0;
   ast.NameList;
}
p:match"import_stmt" {
   m.P"import" * idsafe * s * ((
      m.Cg(m.V"ident", "name") * s
      * "from" * idsafe * s * m.Cg(m.V"from_path", "from") * (
          s * "as" * idsafe * s * m.Cg(m.V"ident", "alias")
        + s * "in" * idsafe * s * m.Cg(m.V"ident", "into")
      )
   ) + (
      m.Cg(m.V"name_list", "list") * s
      * "from" * idsafe * s * m.Cg(m.V"from_path", "from")
   ) + (
      m.P"from" * idsafe * s * m.Cg(m.V"from_path", "from")
   ) + p:error"Syntax error in import statement");
   ast.Import;
}

------------------------------------------------------------------------------
-- PEG rules
------------------------------------------------------------------------------
p:match"rule_decl" {
   m.P"rule" * idsafe * s * m.Cg(m.V"ident", 'name') * s
   * m.Cg(m.Ct((s * m.P"is" * idsafe * s * m.V"ident")^1), "trait")^-1 * s
   * m.P"{" * s * m.Cg(m.V"rule_body", "body") * s * p:expect"}";
   ast.Rule;
}
p:match"pattern_literal" {
   m.P"/" * s * m.V"rule_expr" * s * p:expect"/";
   ast.Pattern;
}
p:match"rule_body" {
   m.P"|"^-1 * s * m.V"rule_expr";
   ast.RuleBody;
}
p:rule"rule_expr" {
  s * m.Cf(m.Cg(m.V"rule_seq") * m.Cg(s * "|" * s * m.V"rule_seq")^0, function(a, b)
      return ast.RuleAlt{ tag = 'rule_alt', pos = a.pos, a, b }
  end)
}
p:match"rule_range" {
   m.Cs(m.P(1) * (m.P"-" / "") * (m.P(1) - "]"));
   ast.RuleRange;
}
p:rule"rule_item" {
   m.V"rule_ref" + m.V"rule_range" + m.C(m.P(1))
}
p:match"rule_class" {
   m.P"[" * m.Cg(m.C"^"^-1 * m.V"rule_item" * (m.V"rule_item" - "]")^0) * "]";
   ast.RuleClass;
}
p:rule"rule_expr_follow" {
   m.P"|" + ")" + "}" + ":}" + "~}" + '`}' + '%}' + '@}' + '/' + -1
}
p:match"rule_seq" {
  m.V"rule_prefix"^0 * (#m.V"rule_expr_follow" + p:error"pattern error");
  ast.RuleSeq;
}
p:rule"rule_prefix" {
     m.C"&" * s * m.V"rule_prefix"
   + m.C"!" * s * m.V"rule_prefix"
   + m.V"rule_suffix"
}
p:rule"rule_suffix" {
   m.Cf(
      m.Cg(m.V"rule_primary") * s * m.Cg((m.V"rule_prod" + m.V"rule_rep") * s)^1,
      function(a, o, b, ...)
         if o == '->' or o == '=>' or o == "~>" then
            return ast.RuleProd{ tag = 'rule_prod', pos = a.pos, oper = o, a, b }
         else
            return ast.RuleRep{ tag = 'rule_rep', pos = a.pos, oper = o, a, b, ... }
         end
      end
   )
   + m.V"rule_primary" * s
}
p:rule"rule_primary" {
     m.V"rule_group"
   + m.V"rule_term"
   + m.V"rule_class"
   + m.V"rule_group_capt"
   + m.V"rule_back_capt"
   + m.V"rule_predef"
   + m.V"rule_pos_capt"
   + m.V"rule_sub_capt"
   + m.V"rule_const_capt"
   + m.V"rule_hash_capt"
   + m.V"rule_array_capt"
   + m.V"rule_simple_capt"
   + m.V"rule_any"
   + m.V"rule_ref"
}
p:match"rule_term" {
   m.V"string";
   ast.RuleTerm;
}
p:rule"rule_rep" {
   m.C"+" + m.C"*" + m.C"?" + (m.C"^" * m.V"number")
}
p:rule"rule_prod" {
     m.C"->" * s * m.V"term"
   + m.C"=>" * s * m.V"term"
   + m.C"~>" * s * m.V"term"
}
p:match"rule_group" {
   "(" * s * m.V"rule_expr" * s * ")";
   ast.RuleGroup
}
p:match"rule_group_capt" {
   "{:" * m.Cg(m.V"ident" * ":" + m.Cc(nil), "name") * m.V"rule_expr" * ":}";
   ast.RuleGroupCapt
}
p:match"rule_back_capt" {
   "=" * m.V"ident";
   ast.RuleBackCapt;
}
p:match"rule_predef" {
   "%" * m.V"ident";
   ast.RulePredef;
}
p:match"rule_pos_capt" {
   m.P"{}";
   ast.RulePosCapt
}
p:match"rule_sub_capt" {
   "{~" * m.V"rule_expr" * "~}";
   ast.RuleSubCapt
}
p:match"rule_const_capt" {
   "{`" * s * m.V"expr" * s * "`}";
   ast.RuleConstCapt
}
p:match"rule_hash_capt" {
   "{%" * s * m.V"rule_expr" * s * "%}";
   ast.RuleHashCapt
}
p:match"rule_array_capt" {
   "{@" * s * m.V"rule_expr" * s * "@}";
   ast.RuleArrayCapt
}
p:match"rule_simple_capt" {
   "{" * m.V"rule_expr" * "}";
   ast.RuleSimpleCapt
}
p:match"rule_any" {
   m.P".";
   ast.RuleAny
}
p:match"rule_ref" {
   m.P"<" * (
      m.V"ident" + "{" * s * m.V"expr" * s * "}"
   ) * ">";
   ast.RuleRef
}

------------------------------------------------------------------------------
-- Expressions
------------------------------------------------------------------------------
local expr_base = p:express"expr_base" :primary"term" :make(ast.Expr)

expr_base:op_infix("&&") :prec(3) :make(ast.OpInfix)
expr_base:op_infix("||") :prec(4) :make(ast.OpInfix)
expr_base:op_infix("|", "^", "&"):prec(6) :make(ast.OpInfix)
expr_base:op_prefix("!"):prec(6) :make(ast.OpPrefix)
expr_base:op_infix("like", "!=", "==", "=~", "!~"):prec(7) :make(ast.OpInfix)
expr_base:op_infix(">>>", ">>", "<<"):prec(9) :make(ast.OpInfix)
expr_base:op_infix("~", "+", "-"):prec(10) :make(ast.OpInfix)
expr_base:op_infix("*", "/", "%"):prec(20) :make(ast.OpInfix)
expr_base:op_prefix("typeof", "delete", "+", "-"):prec(30) :make(ast.OpPrefix)
expr_base:op_infix("**"):prec(35) :make(ast.OpInfix)
expr_base:op_prefix("~","#"):prec(35) :make(ast.OpPrefix)
expr_base:op_ternary"?:":prec(2) :make(ast.OpTernary)

------------------------------------------------------------------------------
-- Full Expression
------------------------------------------------------------------------------
local expr = expr_base:clone"expr"
expr:op_infix(">=", "<=>", "<=", "<", ">", "in"):prec(8) :make(ast.OpInfix)

------------------------------------------------------------------------------
-- No-in Expression
------------------------------------------------------------------------------
local expr_noin = expr_base:clone"expr_noin"
expr_noin:op_infix(">=", "<=>", "<=", "<", ">"):prec(8) :make(ast.OpInfix)

------------------------------------------------------------------------------
-- List Expression
------------------------------------------------------------------------------
local list_expr = p:express"list_expr" :primary"expr" :make(ast.Expr)
list_expr:op_listfix"," :prec(1) :make(ast.OpListfix)

------------------------------------------------------------------------------
-- List No-in Expression
------------------------------------------------------------------------------
local list_expr_noin = p:express"list_expr_noin" :primary"expr_noin" :make(ast.Expr)
list_expr_noin:op_listfix"," :prec(1) :make(ast.OpListfix)

function parse(source)
   return assert(p:parse(source), "failed to parse")
end

