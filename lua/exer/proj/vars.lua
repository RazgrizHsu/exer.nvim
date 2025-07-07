local M = {}

function M.expandVars(cmd)
  if type(cmd) == 'table' then
    local exp = {}
    for _, c in ipairs(cmd) do
      table.insert(exp, M.expandVars(c))
    end
    return exp
  end

  local vars = {
    file = vim.api.nvim_buf_get_name(0),
    filename = vim.fn.expand('%:t'),
    dir = vim.fn.expand('%:p:h'),
    ext = vim.fn.expand('%:e'),
    filetype = vim.api.nvim_get_option_value('filetype', { buf = 0 }),
    name = vim.fn.expand('%:t:r'),
    fullname = vim.fn.expand('%:p:r'),
    root = vim.fn.getcwd(),
    cwd = vim.fn.getcwd(),
    servername = vim.v.servername or '',
    dirname = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'),
    stem = vim.fn.expand('%:t'),
  }

  local exp = cmd
  for var, val in pairs(vars) do
    local safeVal = val:gsub('%%', '%%%%')
    exp = exp:gsub('%${' .. var .. '}', safeVal)
  end

  return exp
end

return M
