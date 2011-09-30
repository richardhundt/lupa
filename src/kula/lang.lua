module("kula.lang", package.seeall)

require"kula.lang.context"
require"kula.lang.grammar"
require"kula.lang.kernel"

function runfile(file,...)
   local sfh = io.open(file)
   local src = sfh:read"*a"
   local ctx = context.Context.new(src, file)
   local ast = grammar.parse(src)

   --print("AST:", ast)
   local lua = ctx:compile(ast)
   print("LUA:", lua)

   --local main = coroutine.wrap(assert(loadstring(lua,'='..file)))
   local main = assert(loadstring(lua,'='..file))
   --[[
   local outc = io.open(file:gsub('%.ku$','.lua'), "w+")
   outc:write(lua)
   outc:close()
   --]]
   main(file,...)
end

function make(src, name)
   local ctx = context.Context.new(src, name)
   local ast = grammar.parse(src)
   local lua = ctx:compile(ast)
   print("LUA:", lua, "NAME:", name)
   local sid
   if name then
      sid = '='..name
   end
   -- using a coroutine breaks eval()'s setfenv
   --local main = coroutine.wrap(assert(loadstring(lua,sid)))
   local main = assert(loadstring(lua,sid))

   --[[
   local outc = io.open(name:gsub('%.ku$','.lua'), "w+")
   outc:write(lua)
   outc:close()
   --]]
   return main
end

local sys = require"sys"
function make_eval(src, name)
   local tic = sys.period()
   tic:start()
   local ctx = context.Context.new(src, name)
   local ast = grammar.parse(src)
   print("parse:", tic:get())
   ast.tag = 'eval'
   tic:start()
   local lua = ctx:compile(ast)
   print("compile:", tic:get())
   local sid
   if name then
      sid = '='..name
   else
      sid = "="..src
   end
   local main = assert(loadstring(lua,sid))
   return main
end


unit = kula.lang.kernel.unit

kula.path = "./?.ku;./lib/?.ku;./src/?.ku"
package.loaders[#package.loaders + 1] = function(modname)
   local filename = modname:gsub("%.", "/")
   for path in kula.path:gmatch"([^;]+)" do
      if path ~= "" then
         local filepath = path:gsub("?", filename)
         local file = io.open(filepath, "r")
         if file then
            local src = file:read("*a")
            local mod = make(src, filepath)
            package.loaded[modname] = mod
            return mod
         end
      end
   end
end

