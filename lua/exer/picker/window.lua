local M = {}

-- Border color configuration
local BORDER_COLOR = 'DiagnosticWarn'

local function calcWinListOpts(cntOpts)
  local wWin = 66
  local itmMax = 15
  local itmActual = math.min(cntOpts, itmMax)
  local hWin = itmActual + 1

  local wEditor = vim.o.columns
  local hEditor = vim.o.lines

  local hTotal = hWin + 3
  local row = math.floor((hEditor - hTotal) / 2)
  local col = math.floor((wEditor - wWin) / 2)

  return {
    relative = 'editor',
    width = wWin,
    height = hWin,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Exer ',
    title_pos = 'center',
    focusable = false,
  }
end

local function calcWinInputOpts(cfgWinLst)
  return {
    relative = 'editor',
    width = cfgWinLst.width,
    height = 1,
    row = cfgWinLst.row + cfgWinLst.height + 2,
    col = cfgWinLst.col,
    style = 'minimal',
    border = {
      { '╭', BORDER_COLOR },
      { '─', BORDER_COLOR },
      { '╮', BORDER_COLOR },
      { '│', BORDER_COLOR },
      { '╯', BORDER_COLOR },
      { '─', BORDER_COLOR },
      { '╰', BORDER_COLOR },
      { '│', BORDER_COLOR },
    },
  }
end

function M.createListWindow(cntOpts)
  local listWinOpts = calcWinListOpts(cntOpts)

  local listBuf = vim.api.nvim_create_buf(false, true)
  vim.bo[listBuf].buftype = 'nofile'
  vim.bo[listBuf].bufhidden = 'wipe'
  vim.bo[listBuf].filetype = 'raz-picker-list'
  vim.bo[listBuf].modifiable = false

  local listWin = vim.api.nvim_open_win(listBuf, false, listWinOpts)
  vim.wo[listWin].number = false
  vim.wo[listWin].relativenumber = false
  vim.wo[listWin].signcolumn = 'no'
  vim.wo[listWin].wrap = false
  vim.wo[listWin].cursorline = false
  vim.wo[listWin].colorcolumn = ''

  return listBuf, listWin, listWinOpts
end

function M.createInputWindow(listWinOpts)
  local inputWinOpts = calcWinInputOpts(listWinOpts)

  local inputBuf = vim.api.nvim_create_buf(false, true)
  vim.bo[inputBuf].buftype = 'nofile'
  vim.bo[inputBuf].bufhidden = 'wipe'
  vim.bo[inputBuf].filetype = 'raz-picker-input'
  vim.bo[inputBuf].modifiable = false

  local inputWin = vim.api.nvim_open_win(inputBuf, true, inputWinOpts)
  vim.wo[inputWin].number = false
  vim.wo[inputWin].relativenumber = false
  vim.wo[inputWin].signcolumn = 'no'
  vim.wo[inputWin].wrap = false
  vim.wo[inputWin].cursorline = false
  vim.wo[inputWin].colorcolumn = ''
  vim.wo[inputWin].spell = false
  vim.wo[inputWin].list = false

  return inputBuf, inputWin
end

function M.closeWindows(listWin, inputWin)
  if listWin and vim.api.nvim_win_is_valid(listWin) then vim.api.nvim_win_close(listWin, true) end
  if inputWin and vim.api.nvim_win_is_valid(inputWin) then vim.api.nvim_win_close(inputWin, true) end
end

return M
