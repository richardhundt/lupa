module("kula.lang", package.seeall)

require"kula.lang.context"
require"kula.lang.grammar"
require"kula.lang.kernel"

local usage = [[
   kula <source>
   kula -o <outfile> <source>
]]

function getopt(...)
   local opt = { }
   local idx = 0
   local len = select('#', ...)
   while idx < len do
      idx = idx + 1
      local arg = select(idx, ...)
      if arg:sub(1,1) == '-' then
         local o = arg:sub(2)
         if o == 'o' then
            idx = idx + 1
            opt['o'] = select(idx, ...)
         elseif o == 'a' then
            opt['a'] = true
         elseif o == 'l' then
            opt['l'] = true
         elseif o == 'b' then
            idx = idx + 1
            opt['b'] = select(idx, ...)
         else
            error('unknown option: '..arg, 2)
         end
      else
         opt['file'] = arg
      end
   end
   return opt
end

function run(...)
   local opt = getopt(...)
   local sfh = io.open(opt.file)
   local src = sfh:read"*a"
   local ctx = context.Context.new(src, opt.file)
   local ast = grammar.parse(src)

   if opt.a then
      print(tostring(ast))
      os.exit(0)
   end

   local lua = ctx:compile(ast)

   if opt.l then
      print(lua)
      os.exit(0)
   end

   --local main = coroutine.wrap(assert(loadstring(lua,'='..file)))
   local main = assert(loadstring(lua,'='..opt.file))
   if opt.o then
      local outc = io.open(opt.o, "w+")
      outc:write(lua)
      outc:close()
   elseif opt.b then
      local outc = io.open(opt.b, "wb+")
      outc:write(string.dump(main))
      outc:close()
   else
      main(opt.file, ...)
   end
end

function make(src, name)
   local ctx = context.Context.new(src, name)
   local ast = grammar.parse(src)
   local lua = ctx:compile(ast)
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

function make_eval(src, name)
   local ctx = context.Context.new(src, name)
   local ast = grammar.parse(src)
   ast.tag = 'eval'
   local lua = ctx:compile(ast)
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

