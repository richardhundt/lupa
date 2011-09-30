module("kula.lang.context", package.seeall)

local table, string = table, string

local native_reserved = {
   'do', 'end', 'then', 'repeat', 'until', 'elseif', 'local'
}
for i=1,#native_reserved do
   local name = native_reserved[i]
   native_reserved[name] = name..'__'
end

Scope = { }
Scope.__index = Scope
Scope.new = function(outer, tag)
   local self = {
      outer   = outer;
      stash   = { };
      entries = { };
      exports = { };
      code    = { };
      tag     = tag or 'block';
   }
   if outer then
      setmetatable(self.stash, { __index = outer.stash })
   end
   return setmetatable(self, Scope)
end
Scope.put = function(self, frag)
   self.code[#self.code + 1] = frag or ''
end
Scope.fput = function(self, fmt, ...)
   local frag = string.format(fmt, ...)
   self.code[#self.code + 1] = frag
end
Scope.define = function(self, base, name, pos, guard)
   local safe = name
   if native_reserved[name] then
      safe = native_reserved[name]
   end
   local info = {
      base  = base;
      name  = safe;
      pos   = pos;
      scope = self;
      guard = guard;
   }
   self.entries[safe] = info
   return info
end
Scope.lookup = function(self, name)
   local safe = name
   if native_reserved[name] then
      safe = native_reserved[name]
   end
   if self.entries[safe] then
      return self.entries[safe], self
   end
   if self.outer then
      return self.outer:lookup(name)
   end
end

Context = { }
Context.__index = Context
Context.native_reserved = native_reserved
Context.new = function(source, name)
   return setmetatable({
      source = source,
      idgen  = 0,
      name   = name or source,
      line   = 1,
      pos    = 0,
   }, Context)
end
Context.sync = function(self, node)
   local pad = ''
   if node.pos then
      if node.pos > self.pos then
         local line = self.line
         local need = 0
         local init = self.pos
         while true do
            local o = string.find(self.source, "\n", init, true)
            if o == nil or o > node.pos then break end
            init = o + 1
            need = need + 1
         end
         if need > 0 then
            pad = string.rep("\n", need)
            self.line = self.line + need
         end
         self.pos = node.pos
      end
      self.pos = node.pos
   end
   return pad
end
Context.error = function(self, mesg)
   print(mesg..', in '..self.name..', line '..self.line)
   os.exit(255)
end
Context.enter = function(self, tag)
   self.scope = Scope.new(self.scope, tag)
   return self.scope
end
Context.leave = function(self, sep)
   local scope = self.scope
   self.scope = self.scope.outer
   return table.concat(scope.code, sep or ' ')
end
Context.find_scope = function(self, tag)
   local cur = self.scope
   if not tag then return cur end
   while cur do
      if cur.tag == tag then return cur end
      cur = cur.outer
   end
   return cur
end
Context.genid = function(self, prefix)
   self.idgen = self.idgen + 1
   prefix = prefix or ''
   return '_'..prefix..self.idgen
end
Context.define = function(self, base, name, node)
   local pos = node.pos or self.pos
   if type(name) == 'table' then
      return self.scope:define(base, name[1], pos, node.guard)
   end
   return self.scope:define(base, name, pos, node.guard)
end
Context.lookup = function(self, name)
   return self.scope:lookup(name)
end
Context.export = function(self, name)
   self.scope.exports[#self.scope.exports + 1] = name
end
Context.get = function(self, node, ...)
   if type(node) ~= 'table' then
      return tostring(node)
   end
   local pad = self:sync(node)
   local out = node:render(self, ...)
   if type(out) == 'string' then
      return pad..out
   else
      self:put(pad)
      return out
   end
end
Context.put = function(self, frag)
   self.scope:put(self:get(frag))
end
Context.fput = function(self, fmt, ...)
   self.scope:fput(fmt, ...)
end
Context.compile = function(self, root)
   self:enter"global"
   self:put(root)
   return self:leave()
end

