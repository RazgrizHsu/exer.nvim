local lg = require('exer.core.log')
local M = {}

function M.findNodeByType(typeNodes)
  local csr = vim.treesitter.get_node()
  if not csr then return nil end

  local cur = csr
  while cur do
    if vim.tbl_contains(typeNodes, cur:type()) then return cur end
    cur = cur:parent()
  end

  return nil
end

function M.isCursorInFunc(namesFunc)
  local nd = M.findNodeByType({ 'call_expression' })
  if not nd then return false end

  local ndFn = nd:child(0)
  if not ndFn then return false end

  local txt = vim.treesitter.get_node_text(ndFn, 0)
  return vim.tbl_contains(namesFunc, txt)
end

function M.getCurrentFuncName()
  local nd = M.findNodeByType({ 'call_expression' })
  if not nd then return nil end

  local ndFn = nd:child(0)
  if not ndFn then return nil end

  return vim.treesitter.get_node_text(ndFn, 0)
end

function M.getTestNameAtCursor()
  local testKs = { 'describe', 'test', 'it' }

  local csr = vim.treesitter.get_node()
  if not csr then return nil end

  local testPath = {}
  local cur = csr
  local depth = 0

  -- traverse up all parent nodes, collect all test level names
  while cur and depth < 20 do
    if cur:type() == 'call_expression' then
      local ndFn = cur:child(0)
      if ndFn then
        local fnm = vim.treesitter.get_node_text(ndFn, 0)

        if vim.tbl_contains(testKs, fnm) then
          local ndArg = cur:child(1)
          if ndArg and ndArg:type() == 'arguments' then
            -- find string argument
            for i = 0, ndArg:child_count() - 1 do
              local cn = ndArg:child(i)
              if cn and (cn:type() == 'string' or cn:type() == 'template_string') then
                local raw = vim.treesitter.get_node_text(cn, 0)
                local nam = raw:gsub('^["\']', ''):gsub('["\']$', ''):gsub('^`', ''):gsub('`$', '')

                if nam and nam ~= '' then
                  -- insert test name at the beginning of path (since we're traversing up)
                  table.insert(testPath, 1, nam)
                  lg.debug('Found test level: ' .. fnm .. " '" .. nam .. "'", 'Test Level')
                  break
                end
              end
            end
          end
        end
      end
    end
    cur = cur:parent()
    depth = depth + 1
  end

  if #testPath > 0 then
    local nameFull = table.concat(testPath, ' ')
    return nameFull
  end

  return nil
end

return M
