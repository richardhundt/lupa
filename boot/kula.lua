#!/usr/bin/env luajit

package.path = ";;./src/?.lua;./lib/?.lua;"..package.path
package.cpath = ";;./lib/?.so;"..package.cpath

local runtime = require"runtime"
local parser  = require"parser"

local function runfile(name, ...)
   local f = io.open(name)
   local s = f:read('*a')
   f:close()
   local l = parser.Kula:match(s)
   print(l)
   local unit = assert(loadstring(l, "="..name))
   return unit(name, ...)
end

runfile(...)

