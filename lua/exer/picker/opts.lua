local M = {}
local mt = { __index = M }

function M.new()
  local self = { items = {} }
  return setmetatable(self, mt)
end

function M:add(text, value)
  table.insert(self.items, { text = text, value = value })
  return self
end

function M:addBu(text, value, name, typeStr)
  table.insert(self.items, {
    text = text,
    value = value,
    type = typeStr or 'Build',
    name = name,
  })
  return self
end

function M:addTf(text, value, name, typeStr)
  table.insert(self.items, {
    text = text,
    value = value,
    type = typeStr or 'Jest',
    name = name,
  })
  return self
end

function M:addProj(text, value, name)
  table.insert(self.items, {
    text = text,
    value = value,
    type = 'Proj',
    name = name,
  })
  return self
end

function M:addLang(text, value, name, typeStr)
  table.insert(self.items, {
    text = text,
    value = value,
    type = typeStr or 'Lang',
    name = name,
  })
  return self
end

function M:build() return self.items end

return M
