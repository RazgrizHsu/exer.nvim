local M = {}

function M.new()
  local self = {
    cmds = {},
    env = {},
    cwd = nil,
  }
  setmetatable(self, { __index = M })
  return self
end

function M:add(cmd)
  table.insert(self.cmds, cmd)
  return self
end

function M:when(condition, cmd)
  if condition then return self:add(cmd) end
  return self
end

function M:rm(path, force)
  local flags = force and '-rf' or '-f'
  return self:add(string.format('rm %s "%s" || true', flags, path))
end

function M:mkdir(path) return self:add(string.format('mkdir -p "%s"', path)) end

function M:run(program, args)
  local cmd = string.format('"%s"', program)
  if args then cmd = cmd .. ' ' .. args end
  return self:add(cmd)
end

function M:compile(compiler, args) return self:add(compiler .. ' ' .. args) end

function M:setenv(key, value)
  self.env[key] = value
  return self
end

function M:cd(path)
  self.cwd = path
  return self
end

function M:build()
  local parts = {}

  for k, v in pairs(self.env) do
    table.insert(parts, string.format('%s="%s"', k, v))
  end

  if self.cwd then table.insert(parts, string.format('cd "%s"', self.cwd)) end

  for _, cmd in ipairs(self.cmds) do
    table.insert(parts, cmd)
  end

  return table.concat(parts, ' && ')
end

return M
