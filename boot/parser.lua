return __unit(function(self,...) __grammar(self,"Kula",function(self) 

    local function error_line(src,pos) 
        local line = 1;
        local index, limit = 1, pos;
        while (index )<=( limit)  do local __break repeat 
            local s, e = src:find(("\n"), index, (true));
            if ((s )==( (nil) ))or(( e )>( limit)) then   do __break = true; break end  end 
            index=(e )+( 1);
            line=(line )+( 1);
         until true if __break then break end end 
         do return line end
     end
    local function error_near(src,pos) 
        if ((#(src) )<(( pos )+( 20))) then  
             do return src:sub(pos) end
        
        else 
             do return (src:sub(pos, (pos )+( 20)))..(("...")) end
         end 
     end
    local function syntax_error(m) 
         do return function(src,pos) 
            local line, near = error_line(src, pos), error_near(src, pos);
            do return error(("SyntaxError: "..tostring((m)or((""))).." on line "..tostring(line).." near '"..tostring(near).."'")) end
         end end
     end

    local id_counter = 9;
    local function genid() 
        id_counter=(id_counter )+(1);
         do return (("_"))..(id_counter) end
     end

    local function quote(c)  do return ("%q"):format(c) end  end

    local nl      = __patt.P( __patt.P(("\n")) );
    local comment = __patt.P( __patt.Cs(
         ((((-nl* __patt.Def("s"))^0* __patt.P(("//"))* (-nl* __patt.P(1))^0* nl) )/( ("\n")))
        + ((__patt.P(("/*")))/((""))* (-__patt.P(("*/"))* ((nl )/( ("\n")) + (__patt.P(1) )/( (""))))^0* ((__patt.P(("*/")) )/( (""))))
    ) );
    local idsafe  = __patt.P( -(__patt.Def("alnum") + __patt.P(("_"))) );
    local s       = __patt.P( (comment + __patt.Def("s"))^0 );
    local semicol = __patt.P( ((__patt.P((";")) )/( ("")))^-1 );
    local digits  = __patt.P( (__patt.Def("digit")* __patt.P(("_"))^-1)^1 );
    local keyword = __patt.P( (
          __patt.P(("var")) + __patt.P(("function")) + __patt.P(("class")) + __patt.P(("with")) + __patt.P(("like")) + __patt.P(("in"))
        + __patt.P(("nil")) + __patt.P(("true")) + __patt.P(("false")) + __patt.P(("typeof")) + __patt.P(("return")) + __patt.P(("as"))
        + __patt.P(("for")) + __patt.P(("throw")) + __patt.P(("method")) + __patt.P(("has")) + __patt.P(("from")) + __patt.P(("break"))
        + __patt.P(("continue")) + __patt.P(("package")) + __patt.P(("import")) + __patt.P(("try")) + __patt.P(("catch"))
        + __patt.P(("finally")) + __patt.P(("if")) + __patt.P(("else")) + __patt.P(("yield")) + __patt.P(("grammar"))
    )* idsafe );

    local prec = Hash({
        [("^^")]  = 4,
        [("*")]   = 5,
        [("/")]   = 5,
        [("%")]   = 5,
        [("+")]   = 6,
        [("-")]   = 6,
        [("~")]   = 6,
        [(">>")]  = 7,
        [("<<")]  = 7,
        [(">>>")] = 7,
        [("<=")]  = 8,
        [(">=")]  = 8,
        [("<")]   = 8,
        [(">")]   = 8,
        [("in")]  = 8,
        [("as")]  = 8,
        [("==")]  = 9,
        [("!=")]  = 9,
        [("&")]   = 10,
        [("^")]   = 11,
        [("|")]   = 12,
        [("&&")]  = 13,
        [("||")]  = 14,
    });

    local unrops = Hash({
        [("!")] = ("not(%s)"),
        [("#")] = ("#(%s)"),
        [("-")] = ("-(%s)"),
        [("~")] = ("__op_bnot(%s)"),
        [("...")] = ("__op_spread(%s)"),
    });

    local binops = Hash({
        [("^^")] = ("(%s)^(%s)"),
        [("*")] = ("(%s)*(%s)"),
        [("/")] = ("(%s)/(%s)"),
        [("%")] = ("(%s)%%(%s)"),
        [("+")] = ("(%s)+(%s)"),
        [("-")] = ("(%s)-(%s)"),
        [("~")] = ("(%s)..(%s)"),
        [(">>")] = ("__op_rshift(%s,%s)"),
        [("<<")] = ("__op_lshift(%s,%s)"),
        [(">>>")] = ("__op_arshift(%s,%s)"),
        [("<=")] = ("(%s)<=(%s)"),
        [(">=")] = ("(%s)>=(%s)"),
        [("<")] = ("(%s)<(%s)"),
        [(">")] = ("(%s)>(%s)"),
        [("in")] = ("__op_in(%s,%s)"),
        [("as")] = ("__op_as(%s,%s)"),
        [("==")] = ("(%s)==(%s)"),
        [("!=")] = ("(%s)~=(%s)"),
        [("&")] = ("__op_band(%s,%s)"),
        [("^")] = ("__op_bxor(%s,%s)"),
        [("|")] = ("__op_bor(%s,%s)"),
        [("&&")] = ("(%s)and(%s)"),
        [("||")] = ("(%s)or(%s)"),
    });

    local function fold_prefix(o,e) 
         do return unrops:__getitem(o):format(e) end
     end


    local function fold_infix(e) 
        local s = Array( e:__getitem(1) );
        for i=2, #(e)  do local __break repeat 
            s:__setitem((#(s) )+( 1),e:__getitem(i));
            while (not(binops:__getitem(s:__getitem(#(s)))) )and( s:__getitem((#(s) )-( 1)))  do local __break repeat 
                local p = s:__getitem((#(s) )-( 1));
                local n = e:__getitem((i )+( 1));
                if ((n )==( (nil) ))or(( prec:__getitem(p) )<=( prec:__getitem(n))) then  
                    local b, o, a = s:pop(), s:pop(), s:pop();
                    if not(binops:__getitem(o)) then  
                        error(("bad expression: "..tostring(e)..", stack: "..tostring(s)..""));
                     end 
                    s:push(binops:__getitem(o):format(a, b));
                
                else 
                    do __break = true; break end
                 end 
             until true if __break then break end end 
         until true if __break then break end end 
         do return s:__getitem(1) end
     end


    





    local function fold_bind(f,...) local e=Tuple(...);
        if (#(f) )==( 1) then  
             do return f:__getitem(1):format(__op_spread(e)) end
         end 
        local b, r = Array( ), Array( __op_spread(e) );
        local t = f:map(genid);
        b:push(("local %s=%s"):format(t:concat((",")),r:concat((","))));
        for i=1, #(f)  do local __break repeat 
            b:__setitem((#(b) )+( 1),f:__getitem(i):format(t:__getitem(i)));
         until true if __break then break end end 
         do return b:concat((";")) end
     end
    local function make_binop_bind(a,o,b) 
        do return Kula:__get_bind_expr():match(((((a)..(("=")))..(a))..(o))..(b)) end
     end

    local function make_params(p) 
        local h = ("");
        if ((#(p) )>( 0 ))and( p:__getitem(#(p)):match(("^%.%.%."))) then  
            local r = p:__getitem(#(p));
            p:__setitem(#(p),("..."));
            h=("local %s=Tuple(...);"):format(r:sub(4));
         end 
         do return p:concat((",")), h end
     end

    local function make_func(p,b) 
        local p, h = make_params(p);
         do return ("function(%s) %s%s end"):format(p,h,b) end
     end

    local function make_func_decl(n,p,b,s) 
        local p, h = make_params(p);
        if ((s )==( ("lexical") ))and( not(n:find(("."),1,(true)))) then  
             do return ("local function %s(%s) %s%s end"):format(n,p,h,b) end
        
        else 
             do return ("function %s(%s) %s%s end"):format(n,p,h,b) end
         end 
     end

    local function make_meth_decl(n,p,b) 
        p:unshift(("self"));
        local p, h = make_params(p);
         do return ("__method(self,%q,function(%s) %s%s end);"):format(n,p,h,b) end
     end

    local function make_trait_decl(n,p,w,b) 
        local p, h = make_params(p);
        
            do return ("__trait(self,%q,{%s},function(self,%s) %s%s end);")
            :format(n,w,p,h,b) end
     end

    local function make_try_stmt(try_body,catch_args,catch_body) 
         do return (
            (((("do local __return;"))..(
            ("__try(function() %s end,function(%s) %s end);") ))..(
            ("if __return then return __spread(__return) end")))..(
            (" end"))
        ):format(try_body, (catch_args )or( ("")), (catch_body )or( (""))) end
     end

    local function make_import_stmt(n,f,a) 
        if (f )==( (nil)) then  

             do return ("__import(self,%s);"):format(n) end
        
         elseif n:isa(Array) then  

            if a then  
                 do return ("__import(self,%s,Array(%s),%s);"):format(f,n:concat((",")),a) end
             else 
                 do return ("__import(self,%s,Array(%s));"):format(f,n:concat((","))) end
             end 
        
        else 

             do return ("__import(self,%s,Hash({[%s]=%s}));"):format(f,n,a) end
         end 
     end

    __rule(self,"__init",
        __patt.Cs( __patt.V("unit") )* (-__patt.P(1) + (syntax_error(("expected <EOF>"))))
    );
    __rule(self,"unit",
        __patt.Cg( __patt.Cc((false)),"set_return")*
        __patt.Cg( __patt.Cc(("global")),"scope")*
        (
            (__patt.Cs( (s* __patt.V("main_body_stmt"))^0* s )
            )/( ("return __unit(function(self,...) %1 end,...)"))
        )
    );
    __rule(self,"main_body_stmt",
         __patt.V("var_decl")
        + __patt.V("func_decl")
        + __patt.V("class_decl")
        + __patt.V("trait_decl")
        + __patt.V("grammar_decl")
        + __patt.V("package_decl")
        + __patt.V("import_stmt")
        + __patt.V("statement")
    );
    __rule(self,"statement",
         __patt.V("if_stmt")
        + __patt.V("try_stmt")
        + __patt.V("for_stmt")
        + __patt.V("for_in_stmt")
        + __patt.V("while_stmt")
        + __patt.V("break_stmt")
        + __patt.V("continue_stmt")
        + __patt.V("block_stmt")
        + __patt.V("bind_stmt")
        + __patt.V("expr_stmt")
    );
    __rule(self,"expr_stmt",
        __patt.Cs( (__patt.V("expr") )/( ("%1;"))* semicol )
    );
    __rule(self,"return_stmt",
        __patt.Cs( (__patt.P(("return")) )/( (""))* idsafe* s* (__patt.Cb("set_return")* (__patt.V("expr_list") )/( function(l,e) 
            if l then  
                 do return ("do __return = {%s}; return end"):format(e) end
             end 
             do return ("do return %s end"):format(e) end
         end)) )
    );
    __rule(self,"break_stmt",
        __patt.Cs( (__patt.C( __patt.P(("break"))* idsafe ) )/( ("do __break = true; break end")) )
    );
    __rule(self,"continue_stmt",
        __patt.Cs( (__patt.C( __patt.P(("continue"))* idsafe ) )/( ("do break end")) )
    );
    __rule(self,"if_stmt",
        __patt.Cs(
        __patt.P(("if"))* idsafe* s* __patt.V("expr")* __patt.Cc((" then "))* s* __patt.V("block")* (
            (s* ((__patt.C(__patt.P(("else"))* idsafe* s* __patt.P(("if"))* idsafe) )/( (" elseif")))* s*
                __patt.V("expr")* __patt.Cc((" then "))* s* __patt.V("block")
            )^0*
            (s* __patt.P(("else"))* idsafe* s* __patt.V("block")* __patt.Cc((" end ")) + __patt.Cc((" end ")))
        )
        )
    );
    __rule(self,"try_stmt",
        __patt.P(("try"))* idsafe* s* __patt.P(("{"))* __patt.Cs( __patt.V("lambda_body")* s )* __patt.P(("}"))*
        ((s* __patt.P(("catch"))* idsafe* s* __patt.P(("("))* s* __patt.V("ident")* s* __patt.P((")"))* s* __patt.P(("{"))* __patt.Cs( __patt.V("lambda_body")* s )* __patt.P(("}")))^-1
        )/( make_try_stmt)
    );
    __rule(self,"import_stmt",
        __patt.Cs( ((
            __patt.P(("import"))* idsafe* s* (__patt.V("import_in") + __patt.V("import_as") + __patt.V("import_from"))
        ) )/( make_import_stmt) )
    );
    __rule(self,"import_as",
        ((__patt.V("ident") )/( quote))* s* __patt.P(("from"))* idsafe* s* ((__patt.V("qname") )/( quote))*
        __patt.P(("as"))* idsafe* s* ((__patt.V("ident") )/( quote))
    );
    __rule(self,"import_in",
        __patt.Ca( ((__patt.V("ident") )/( quote))* (s* __patt.P((","))* s* ((__patt.V("ident") )/( quote)))^0 )* s*
        __patt.P(("from"))* idsafe* s* ((__patt.V("qname") )/( quote))*
        (s* __patt.P(("in"))* idsafe* s* ((__patt.V("ident") )/( quote)))^-1
    );
    __rule(self,"import_from",
        __patt.P(("from"))* idsafe* s* ((__patt.V("qname") )/( quote))
    );
    __rule(self,"for_stmt",
        __patt.Cs( __patt.P(("for"))* idsafe* s* __patt.V("ident")* s* __patt.P(("="))* s* __patt.V("expr")* s* __patt.P((","))* s* __patt.V("expr")*
            (s* __patt.P((","))* s* __patt.V("expr"))^-1* s* __patt.V("loop_body")
        )
    );
    __rule(self,"for_in_stmt",
        __patt.Cs( __patt.P(("for"))* idsafe* s* __patt.V("ident_list")* s* __patt.P(("in"))* s*
            ((__patt.V("expr") )/( ("__op_each(%1)")))* s* __patt.V("loop_body")
        )
    );
    __rule(self,"while_stmt",
        __patt.Cs( __patt.P(("while"))* idsafe* s* __patt.V("expr")* s* __patt.V("loop_body") )
    );
    __rule(self,"loop_body",
        ((__patt.P(("{")) )/( (" do local __break repeat ")))* __patt.V("block_body")* s*
        ((__patt.P(("}")) )/( (" until true if __break then break end end ")))
    );
    __rule(self,"block",
        __patt.Cs( ((__patt.P(("{")) )/( ("")))* __patt.V("block_body")* s* ((__patt.P(("}")) )/( (""))) )
    );
    __rule(self,"block_stmt",
        __patt.Cs( ((__patt.P(("{")) )/( ("do ")))* __patt.V("block_body")* s* ((__patt.P(("}")) )/( (" end"))) )
    );
    __rule(self,"block_body",
        __patt.Cg( __patt.Cb("scope"),"outer")* __patt.Cg( __patt.Cc(("lexical")),"scope")*
        (s* __patt.V("block_body_stmt"))^0*
        __patt.Cg( __patt.Cb("outer"),"scope")
    );
    __rule(self,"block_body_stmt",
         __patt.V("var_decl")
        + __patt.V("func_decl")
        + __patt.V("return_stmt")
        + __patt.V("statement")
    );
    __rule(self,"lambda_body",
        __patt.Cg( __patt.Cb("set_return"),"old_set_return")* __patt.Cg( __patt.Cc((true)),"set_return")*
        __patt.V("block_body")* s*
        __patt.Cg( __patt.Cb("old_set_return"),"set_return")
    );
    __rule(self,"slot_decl",
        __patt.Cs( ((__patt.P(("has"))* idsafe* s* __patt.V("ident")* (s* __patt.P(("="))* s* (__patt.V("expr") + __patt.Cc((""))))^-1* semicol)
            )/( ("__has(self,\"%1\",function(self) return %2 end);"))
        )
    );
    __rule(self,"meth_decl",
        __patt.Cs( ((__patt.P(("method"))* idsafe* s* __patt.V("qname")* s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")"))* s* __patt.P(("{"))*
            __patt.Cs( __patt.V("func_body")* s )*
        __patt.P(("}"))) )/( make_meth_decl) )
    );
    __rule(self,"func_decl",
        __patt.Cs( ((__patt.P(("function"))* idsafe* s* __patt.V("qname")* s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")"))* s* __patt.P(("{"))*
            __patt.Cs( __patt.V("func_body")* s )*
        __patt.P(("}"))* __patt.Cb("scope")) )/( make_func_decl) )
    );
    __rule(self,"func_body",
        __patt.Cg( __patt.Cb("scope"),"outer")* __patt.Cg( __patt.Cc(("lexical")),"scope")*
        (s* __patt.V("func_body_stmt"))^0*
        __patt.Cg( __patt.Cb("outer"),"scope")
    );
    __rule(self,"func_body_stmt",
         __patt.V("var_decl")
        + __patt.V("func_decl")
        + __patt.V("return_stmt")
        + (__patt.V("expr")* (#(s* __patt.P(("}"))) )/( ("do return %1 end")))
        + __patt.V("statement")
    );
    __rule(self,"func",
        __patt.Cs( ((__patt.P(("function"))* idsafe* s* __patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")"))* s* __patt.P(("{"))*
            __patt.Cs( (s* __patt.V("func_body_stmt"))^0* s )*
        __patt.P(("}"))) )/( make_func) )
    );
    __rule(self,"package_decl",
        __patt.P(("package"))* idsafe* s* ((__patt.V("qname") )/( quote))* s* __patt.P(("{"))*
            __patt.Cs( (s* __patt.V("main_body_stmt"))^0* s )*
        (__patt.P(("}")) )/( ("__package(self,%1,function(self) %2 end);"))
    );
    __rule(self,"class_decl",
        __patt.P(("class"))* idsafe* s* __patt.V("ident")* s*
        (__patt.V("class_from") + __patt.Cc(("")))* s*
        (__patt.V("class_with") + __patt.Cc(("")))* s*
        __patt.P(("{"))* __patt.Cs( __patt.V("class_body")* s )* (__patt.P(("}"))
        )/( ("__class(self,\"%1\",{%2},{%3},function(self,super) %4 end);"))
    );
    __rule(self,"trait_decl",
        __patt.P(("trait"))* idsafe* s* __patt.V("ident")* s*
        (__patt.P(("("))* s* __patt.V("param_list")* s* __patt.P((")")) + __patt.Cc(("..."))* __patt.Cc(("")))* s*
        (__patt.V("class_with") + __patt.Cc(("")))* s*
        __patt.P(("{"))* __patt.Cs( __patt.V("class_body")* s )* (__patt.P(("}"))
        )/( make_trait_decl)
    );
    __rule(self,"class_body",
        __patt.Cg( __patt.Cb("scope"),"outer")* __patt.Cg( __patt.Cc(("lexical")),"scope")*
        (s* __patt.V("class_body_stmt"))^0*
        __patt.Cg( __patt.Cb("outer"),"scope")
    );
    __rule(self,"class_from",
        __patt.P(("from"))* idsafe* s* __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
    );
    __rule(self,"class_with",
        __patt.P(("with"))* idsafe* s* __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
    );
    __rule(self,"class_body_stmt",
         __patt.V("var_decl")
        + __patt.V("slot_decl")
        + __patt.V("func_decl")
        + __patt.V("meth_decl")
        + __patt.V("statement")
    );
    __rule(self,"rest",
        __patt.Cs( __patt.C(__patt.P(("...")))* __patt.V("ident") )
    );
    __rule(self,"param_list",
        __patt.Ca( __patt.V("ident")* (s* __patt.P((","))* s* __patt.V("ident"))^0* (s* __patt.P((","))* s* __patt.V("rest"))^-1 + __patt.V("rest") + __patt.Cc((nil)) )
    );
    __rule(self,"ident",
        __patt.C( -keyword* ((__patt.Def("alpha") + __patt.P(("_")))* (__patt.Def("alnum") + __patt.P(("_")))^0) )
    );
    __rule(self,"ident_list",
        __patt.Cs( __patt.V("ident")* (s* __patt.P((","))* s* __patt.V("ident"))^0 )
    );
    __rule(self,"qname",
        __patt.Cs( __patt.V("ident")* ((__patt.C(__patt.P(("::"))) )/( ("."))* __patt.V("ident"))^0 )
    );
    __rule(self,"hexadec",
        __patt.P(("-"))^-1* __patt.P(("0x"))* __patt.Def("xdigit")^1
    );
    __rule(self,"decimal",
        __patt.P(("-"))^-1* digits* (__patt.P(("."))* digits)^-1* ((__patt.P(("e"))+__patt.P(("E")))* __patt.P(("-"))^-1* digits)^-1
    );
    __rule(self,"number",
        __patt.C( __patt.V("hexadec") + __patt.V("decimal") )
    );
    __rule(self,"string",
        __patt.Cs( ((__patt.V("qstring") + __patt.V("astring")) )/( ("(%1)")) )
    );
    __rule(self,"qstring",
        __patt.Cs(
            (((__patt.P(("\"\"\"")) )/( ("\"")))* (
                __patt.V("string_expr")
                + __patt.Cs( (__patt.P(("\\\\")) + __patt.P(("\\\"")) + (__patt.P(("\\$")))/(("$")) + -(__patt.P(("\"\"\"")) + __patt.V("string_expr"))*__patt.P(1))^1 )
            )^0* ((__patt.P(("\"\"\"")) )/( ("\""))))
            +
            (__patt.P(("\""))* (
                __patt.V("string_expr")
                + __patt.Cs( (__patt.P(("\\\\")) + __patt.P(("\\\"")) + (__patt.P(("\\$")))/(("$")) + -(__patt.P(("\"")) + __patt.V("string_expr"))*__patt.P(1))^1 )
            )^0* __patt.P(("\"")))
        )
    );
    __rule(self,"astring",
        (__patt.Cs(
            ((__patt.P(("'''")) )/( ("")))*
            (__patt.P(("\\\\")) + __patt.P(("\\'")) + (-__patt.P(("'''"))* __patt.P(1)))^0*
            ((__patt.P(("'''")) )/( ("")))
            +
            ((__patt.P(("'")) )/( ("")))* (__patt.P(("\\\\")) + __patt.P(("\\'")) + (-__patt.P(("'"))* __patt.P(1)))^0* ((__patt.P(("'")) )/( ("")))
        ) )/( quote)
    );
    __rule(self,"string_expr",
        __patt.Cs( ((__patt.P(("${")) )/( ("")))* s* ((__patt.V("expr") )/( ("\"..tostring(%1)..\"")))* s* ((__patt.P(("}")) )/( (""))) )
    );
    __rule(self,"vnil",
        __patt.Cs( __patt.C( __patt.P(("nil")) )* (idsafe )/( ("(nil)")) )
    );
    __rule(self,"vtrue",
        __patt.Cs( __patt.C( __patt.P(("true")) )* (idsafe )/( ("(true)")) )
    );
    __rule(self,"vfalse",
        __patt.Cs( __patt.C( __patt.P(("false")) )* (idsafe )/( ("(false)")) )
    );
    __rule(self,"range",
        __patt.Cs( ((
            __patt.P(("["))* s* __patt.V("expr")* s* __patt.P((":"))* s* __patt.V("expr")* ( s* __patt.P((":"))* s* __patt.V("expr") + __patt.Cc(("1")) )* s* __patt.P(("]"))
        ) )/( ("Range(%1,%2,%3)")) )
    );
    __rule(self,"array",
        __patt.Cs(
            ((__patt.C(__patt.P(("["))) )/( ("Array(")))* s*
            (__patt.V("array_elements") + __patt.Cc(("")))* s*
            ((__patt.C(__patt.P(("]"))) )/( (")")) + (syntax_error(("expected ']'"))))
        )
    );
    __rule(self,"array_elements",
        __patt.V("expr")* ( s* __patt.P((","))* s* __patt.V("expr") )^0* (s* __patt.P((",")))^-1
    );
    __rule(self,"hash",
        __patt.Cs(
            ((__patt.C(__patt.P(("{"))) )/( ("Hash({")))* s*
            (__patt.V("hash_pairs") + __patt.Cc(("")))* s*
            ((__patt.C(__patt.P(("}"))) )/( ("})")) + (syntax_error(("expected '}'"))))
        )
    );
    __rule(self,"hash_pairs",
        __patt.V("hash_pair")* (s* __patt.P((","))* s* __patt.V("hash_pair"))^0* (s* __patt.P((",")))^-1
    );
    __rule(self,"hash_pair",
        (__patt.V("ident") + __patt.P(("["))* s* __patt.V("expr")* s* (__patt.P(("]")) + (syntax_error(("expected ']'")))))* s*
        __patt.P(("="))* s* __patt.V("expr")
    );
    __rule(self,"primary",
         __patt.V("ident")
        + __patt.V("range")
        + __patt.V("number")
        + __patt.V("string")
        + __patt.V("vnil")
        + __patt.V("vtrue")
        + __patt.V("vfalse")
        + __patt.V("array")
        + __patt.V("hash")
        + __patt.V("func")
        + __patt.V("pattern")
        + __patt.P(("("))* s* __patt.V("expr")* s* __patt.P((")"))
    );
    __rule(self,"call_expr",
        __patt.V("ident")* s* __patt.V("paren_expr")
    );
    __rule(self,"paren_expr",
        __patt.P(("("))* s* ( __patt.V("expr_list") + __patt.Cc(("")) )* s* __patt.P((")"))
    );
    __rule(self,"member_expr",
        __patt.Cs( s* ((__patt.C(__patt.P(("."))) )/( (":")))* (s* (__patt.V("ident") )/( ("__get_%1()"))) + ((__patt.C(__patt.P(("::"))) )/( (".")))* s* __patt.V("ident") )
    );
    __rule(self,"method_expr",
        __patt.Cs( s* ((__patt.C(__patt.P(("."))) )/( (":")) + (__patt.C(__patt.P(("::"))) )/( (".")))* (s* (__patt.V("call_expr") )/( ("%1(%2)"))) )
    );
    __rule(self,"term",
        __patt.Cs( __patt.V("primary")* (
            __patt.V("suffix_expr") + __patt.V("method_expr") + __patt.V("member_expr")
        )^0 )
    );
    __rule(self,"suffix_expr",
         __patt.Cs( ((__patt.P(("[")) )/( (":__getitem(")))* s* __patt.V("expr")* s* ((__patt.P(("]")) )/( (")"))) )
        + __patt.Cs( __patt.P(("("))* s* __patt.V("expr_list")^-1* s* __patt.P((")")) )
    );
    __rule(self,"expr_list",
        __patt.Cs( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0 )
    );
    __rule(self,"expr",
        __patt.Cs( __patt.V("infix_expr") + __patt.V("prefix_expr") )
    );


    local binop_patt = __patt.P((
        __patt.P(("+")) + __patt.P(("-")) + __patt.P(("~")) + __patt.P(("^^")) + __patt.P(("*")) + __patt.P(("/")) + __patt.P(("%")) + __patt.P(("^")) + __patt.P((">>>")) + __patt.P((">>")) + __patt.P(("<<"))
        + __patt.P(("||")) + __patt.P(("&&")) + __patt.P(("|")) + __patt.P(("&")) + __patt.P(("==")) + __patt.P(("!=")) + __patt.P((">="))+ __patt.P(("<=")) + __patt.P(("<")) + __patt.P((">"))
        + __patt.P(("in"))* idsafe + __patt.P(("like"))* idsafe
    ));

    __rule(self,"infix_expr",
        (__patt.Ca( __patt.Cs( __patt.V("prefix_expr")* s )* (
            __patt.C( binop_patt )*
            __patt.Cs( s* __patt.V("prefix_expr")* (#(s* binop_patt)* s)^-1 )
        )^1 ) )/( fold_infix)
    );


    











































    __rule(self,"prefix_expr",
        (__patt.Cg( __patt.C( __patt.P(("...")) + __patt.P(("!")) + __patt.P(("#")) + __patt.P(("-")) + __patt.P(("~")) )* s* __patt.V("prefix_expr"),nil) )/( fold_prefix)
        + __patt.Cs( s* __patt.V("term") )
    );

    __rule(self,"var_decl",
        (__patt.Cs(
            (__patt.C(__patt.P(("var"))* idsafe) )/( ("local"))* s*
            __patt.V("ident_list")* (s* __patt.P(("="))* s* __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0)^-1
        ) )/( ("%1;"))* semicol
    );


    __rule(self,"bind_stmt",
        __patt.Cs( ((__patt.V("bind_expr") + __patt.V("bind_binop_expr")) )/( ("%1;"))* semicol )
    );
    __rule(self,"bind_expr",
        __patt.Cs( __patt.V("bind_list")* s* __patt.P(("="))* s* (__patt.Cg( __patt.V("expr")* (s* __patt.P((","))* s* __patt.V("expr"))^0,nil) )/( fold_bind) )
     );
    __rule(self,"bind_binop",
        __patt.C( __patt.P(("+")) + __patt.P(("-")) + __patt.P(("*")) + __patt.P(("/")) + __patt.P(("%")) + __patt.P(("||")) + __patt.P(("|"))+ __patt.P(("&&"))
        + __patt.P(("&")) + __patt.P(("^^")) + __patt.P(("^")) + __patt.P(("~")) + __patt.P((">>>")) + __patt.P((">>")) + __patt.P(("<<"))
        )* __patt.P(("="))
    );
    __rule(self,"bind_binop_expr",
        __patt.Cs( (__patt.Cg(
        #(__patt.V("bind_term")* s* __patt.V("bind_binop"))* __patt.C((-__patt.V("bind_binop")* __patt.P(1))^1)* s* __patt.V("bind_binop")* s* __patt.V("expr"),nil) )/( make_binop_bind) )
    );
    __rule(self,"bind_list",
        __patt.Ca( __patt.V("bind_term")* (s* __patt.P((","))* s* __patt.V("bind_term"))^0 )
    );
    __rule(self,"bind_term",
        __patt.Cs( (__patt.V("call_expr")+__patt.V("primary"))* __patt.V("bind_member") + ((__patt.V("ident") )/( ("%1=%%s"))) )
    );
    __rule(self,"bind_member",
         (__patt.V("bind_slot")+__patt.V("bind_name")+__patt.V("bind_item"))* #(s* (__patt.V("bind_binop")+__patt.P(("="))+__patt.P((","))))
        + (__patt.V("method_expr")+__patt.V("member_expr"))* __patt.V("bind_member")
    );
    __rule(self,"bind_slot",
        __patt.Cs( ((__patt.C(__patt.P(("."))) )/( (":")))* (s* (__patt.V("ident") )/( ("__set_%1(%%s)"))) )
    );
    __rule(self,"bind_item",
        __patt.Cs( ((__patt.C(__patt.P(("["))) )/( (":")))* (s* (__patt.V("expr") )/( ("__setitem(%1,%%s)")))* ((__patt.C(__patt.P(("]"))) )/( (""))) )
    );
    __rule(self,"bind_name",
        __patt.Cs( ((__patt.C(__patt.P(("::"))) )/( (".")))* (s* (__patt.V("ident") )/( ("%1=%%s"))) )
    );


    __rule(self,"pattern",
        __patt.P(("/"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("/")) )/( ("__patt.P(%1)"))
    );
    __rule(self,"grammar_decl",
        __patt.Cs( ((
            __patt.P(("grammar"))* idsafe* s* __patt.V("ident")* s*
            __patt.P(("{"))* __patt.Cs( __patt.V("grammar_body")* s )* __patt.P(("}"))
        ) )/( ("__grammar(self,\"%1\",function(self) %2 end);")) )
    );
    __rule(self,"grammar_body",
        __patt.Cg( __patt.Cb("scope"),"outer")* __patt.Cg( __patt.Cc(("lexical")),"scope")*
        (s* __patt.V("grammar_body_stmt"))^0*
        __patt.Cg( __patt.Cb("outer"),"scope")
    );
    __rule(self,"grammar_body_stmt",
         __patt.V("rule_decl")
        + __patt.V("var_decl")
        + __patt.V("func_decl")
        + #__patt.V("return_stmt")* (syntax_error(("return outside of function body")))
        + __patt.V("statement")
    );
    __rule(self,"rule_decl",
        __patt.P(("rule"))* idsafe* s* __patt.V("ident")* s* __patt.P(("{"))* __patt.Cs( s* __patt.V("rule_body")* s )* (__patt.P(("}"))
        )/( ("__rule(self,\"%1\",%2);"))
    );
    __rule(self,"rule_body",
        __patt.V("rule_alt") + __patt.Cc(("__patt.P(nil)"))
    );
    __rule(self,"rule_alt",
        __patt.Cs( ((__patt.C(__patt.P(("|"))) )/( (""))* s)^-1* __patt.V("rule_seq")* (s* ((__patt.C(__patt.P(("|"))) )/( ("+")))* s* __patt.V("rule_seq"))^0 )
    );
    __rule(self,"rule_seq",
        (__patt.Ca( __patt.Cs( s* __patt.V("rule_suffix") )^1 ) )/( function(a)  do return a:concat(("*")) end  end)
    );
    __rule(self,"rule_rep",
        __patt.Cs( (__patt.C(__patt.P(("+"))))/(("^1"))+(__patt.C(__patt.P(("*"))))/(("^0"))+(__patt.C(__patt.P(("?"))))/(("^-1"))+__patt.C(__patt.P(("^"))*s*(__patt.P(("+"))+__patt.P(("-")))*s*(__patt.R("09"))^1) )
    );
    __rule(self,"rule_prefix",
        __patt.Cs( (((__patt.C(__patt.P(("&"))) )/( ("#"))) + ((__patt.C(__patt.P(("!"))) )/( ("-"))))* (__patt.Cs( s* __patt.V("rule_prefix") ) )/( ("%1%2"))
        + __patt.V("rule_primary")
        )
    );

    local prod_oper = __patt.P( __patt.P(("->")) + __patt.P(("~>")) + __patt.P(("=>")) );

    __rule(self,"rule_suffix",
        __patt.Cf((__patt.Cs( __patt.V("rule_prefix")* (#(s* prod_oper)* s)^-1 )* __patt.Cg( __patt.C(prod_oper)* __patt.Cs( s* __patt.V("term") ),nil)^0) , function(a,o,b) 
            if (o )==( ("=>")) then  
                 do return ("__patt.Cmt(%s,%s)"):format(a,b) end
            
             elseif (o )==( ("~>")) then  
                 do return ("__patt.Cf(%s,%s)"):format(a,b) end
             end 
             do return ("(%s)/(%s)"):format(a,b) end
         end)
    );
    __rule(self,"rule_primary",
        ( __patt.V("rule_group")
        + __patt.V("rule_term")
        + __patt.V("rule_class")
        + __patt.V("rule_predef")
        + __patt.V("rule_group_capt")
        + __patt.V("rule_back_capt")
        + __patt.V("rule_sub_capt")
        + __patt.V("rule_const_capt")
        + __patt.V("rule_hash_capt")
        + __patt.V("rule_array_capt")
        + __patt.V("rule_simple_capt")
        + __patt.V("rule_any")
        + __patt.V("rule_ref")
        )* (s* __patt.V("rule_rep"))^0
    );
    __rule(self,"rule_group",
        __patt.Cs( __patt.P(("("))* s* __patt.V("rule_alt")* s* __patt.P((")")) )
    );
    __rule(self,"rule_term",
        __patt.Cs( (__patt.V("string") )/( ("__patt.P(%1)")) )
    );
    __rule(self,"rule_class",
        __patt.Cs(
            ((__patt.P(("[")) )/( ("")))* ((__patt.P(("^")) )/( ("__patt.P(1)-")))^-1*
            ((__patt.Ca( (-__patt.P(("]"))* __patt.V("rule_item"))^1 ) )/( function(a)  do return ((("("))..(a:concat(("+"))))..((")")) end  end))*
            ((__patt.P(("]")) )/( ("")))
        )
    );
    __rule(self,"rule_item",
        __patt.Cs( __patt.V("rule_predef") + __patt.V("rule_range")
        + (__patt.C(__patt.P(1)) )/( function(c)  do return ("__patt.P(%q)"):format(c) end  end)
        )
    );
    __rule(self,"rule_predef",
        __patt.Cs( __patt.P(("%"))* (__patt.V("ident") )/( ("__patt.Def(\"%1\")")) )
    );
    __rule(self,"rule_range",
        (__patt.Cs( __patt.P(1)* ((__patt.P(("-")))/(("")))* -__patt.P(("]"))* __patt.P(1) ) )/( function(r)  do return ("__patt.R(%q)"):format(r) end  end)
    );
    __rule(self,"rule_any",
        __patt.Cs( (__patt.P((".")) )/( ("__patt.P(1)")) )
    );
    __rule(self,"rule_ref",
        __patt.Cs(
        ((__patt.P(("<")) )/( ("")))* s*
            ( (__patt.V("ident") )/( ("__patt.V(\"%1\")"))
            + ((__patt.P(("{")) )/( ("(")))* s* __patt.V("expr")* s* ((__patt.P(("}")) )/( (")")))
            )* s*
        ((__patt.P((">")) )/( ("")))
        + __patt.V("qname")
        )
    );
    __rule(self,"rule_group_capt",
        __patt.Cs( __patt.P(("{:"))* (((__patt.V("ident") )/( quote)* __patt.P((":"))) + __patt.Cc(("nil")))* __patt.Cs( s* __patt.V("rule_alt") )* s* (__patt.P((":}"))
        )/( ("__patt.Cg(%2,%1)"))
        )
    );
    __rule(self,"rule_back_capt",
        __patt.P(("="))* (((__patt.V("ident") )/( quote)) )/( ("__patt.Cb(%1)"))
    );
    __rule(self,"rule_sub_capt",
        __patt.P(("{~"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("~}")) )/( ("__patt.Cs(%1)"))
    );
    __rule(self,"rule_const_capt",
        __patt.P(("{`"))* __patt.Cs( s* __patt.V("expr")* s )* (__patt.P(("`}")) )/( ("__patt.Cc(%1)"))
    );
    __rule(self,"rule_hash_capt",
        __patt.P(("{%"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("%}")) )/( ("__patt.Ch(%1)"))
    );
    __rule(self,"rule_array_capt",
        __patt.P(("{@"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("@}")) )/( ("__patt.Ca(%1)"))
    );
    __rule(self,"rule_simple_capt",
        __patt.P(("{"))* __patt.Cs( s* __patt.V("rule_alt")* s )* (__patt.P(("}")) )/( ("__patt.C(%1)"))
    );
 end);

 end,...)
