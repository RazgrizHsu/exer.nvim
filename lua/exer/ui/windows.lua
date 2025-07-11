local M = {}
local syntax = require('exer.ui.syntax')
local config = require('exer.ui.config')

local state = {
  listW = nil,
  listB = nil,
  palW = nil,
  palB = nil,
  keysW = nil,
  keysB = nil,
}

M.listW = nil
M.listB = nil
M.palW = nil
M.palB = nil
M.keysW = nil
M.keysB = nil

local function calcDims(cfg)
  local win_height, win_width

  if type(cfg.height) == 'number' and cfg.height < 1 then
    win_height = math.floor(vim.o.lines * cfg.height)
  else
    win_height = cfg.height
  end

  if type(cfg.list_width) == 'number' and cfg.list_width < 1 then
    win_width = math.floor(vim.o.columns * cfg.list_width)
  else
    win_width = cfg.list_width
  end

  return win_height, win_width
end

local function calcPos(win_height, win_width)
  local wDtl = vim.o.columns - win_width - 4 -- Space for borders and gap
  local hAvail = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - 2
  local rowS = hAvail - win_height
  if rowS < 0 then rowS = 0 end
  local colS = 0

  return rowS, colS, wDtl
end

local function createBuf(name, filetype, modifiable)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = filetype or 'raz-tasks'
  vim.bo[buf].modifiable = modifiable or false
  vim.api.nvim_buf_set_name(buf, name)
  return buf
end

function M.createMain(cfg)
  local win_height, win_width = calcDims(cfg)
  local rowS, colS, wDtl = calcPos(win_height, win_width)

  state.listB = createBuf('Raz Tasks', 'raz-tasks', false)
  state.listW = vim.api.nvim_open_win(state.listB, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = rowS,
    col = colS,
    style = 'minimal',
    border = 'rounded',
    title = '─Task List',
    title_pos = 'left',
  })
  syntax.apply(state.listB)

  state.palB = createBuf('TaskPanel - Active', 'raz-panel', false)
  state.palW = vim.api.nvim_open_win(state.palB, false, {
    relative = 'editor',
    width = wDtl,
    height = win_height,
    row = rowS,
    col = colS + win_width + 3,
    style = 'minimal',
    border = 'rounded',
    title = '─TaskPanel',
    title_pos = 'left',
  })

  vim.bo[state.palB].modifiable = true
  vim.api.nvim_buf_set_lines(state.palB, 0, -1, false, {
    'TaskPanel',
    '─────────────────────────────────────────',
    '',
    'Select a task from the list to view panel',
  })
  vim.bo[state.palB].modifiable = false
  syntax.apply(state.palB)

  vim.wo[state.listW].number = false
  vim.wo[state.listW].relativenumber = false
  vim.wo[state.listW].signcolumn = 'no'
  -- vim.wo[state.listW].cursorline = true
  -- vim.wo[state.listW].cursorcolumn = false
  vim.wo[state.palW].number = false
  vim.wo[state.palW].relativenumber = false
  vim.wo[state.palW].signcolumn = 'no'

  M.listW = state.listW
  M.listB = state.listB
  M.palW = state.palW
  M.palB = state.palB

  return state.listW, state.listB, state.palW, state.palB
end

function M.createKeysHelp(cfg)
  if not state.listW then return end

  local win_height, win_width = calcDims(cfg)
  local rowS, colS, _ = calcPos(win_height, win_width)

  state.keysB = createBuf('Keys Help', 'raz-keys', true)
  local rowKey = rowS + win_height
  local colKey = colS + 1

  state.keysW = vim.api.nvim_open_win(state.keysB, false, {
    relative = 'editor',
    width = win_width,
    height = 1,
    row = rowKey,
    col = colKey,
    style = 'minimal',
    focusable = false,
    zindex = 100,
  })

  local txtKey = ' 󰌑:view  ' .. config.keymaps.stop_task .. ':stop  ' .. config.keymaps.clear_completed .. ':clear  ' .. config.keymaps.close_ui .. ':quit  '
  vim.api.nvim_buf_set_lines(state.keysB, 0, -1, false, { txtKey })

  vim.api.nvim_set_hl(0, 'RazKeysBlock', {
    bg = '#3c3836',
    fg = '#ebdbb2',
  })

  vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal', { win = state.keysW })
  vim.api.nvim_buf_set_extmark(state.keysB, vim.api.nvim_create_namespace('raz_keys'), 0, 0, {
    end_col = #txtKey,
    hl_group = 'RazKeysBlock',
  })

  M.keysW = state.keysW
  M.keysB = state.keysB

  return state.keysW, state.keysB
end

function M.createPanelBuffer(tid)
  if state.palB and vim.api.nvim_buf_is_valid(state.palB) then
    local curBuf = vim.api.nvim_win_get_buf(state.palW)
    if curBuf == state.palB then return state.palB end
  end

  local bufName = 'Task Output'
  if tid then
    local co = require('exer.core')
    local tsk = co.tsk.get(tid)
    if tsk then bufName = string.format('Task #%d - %s', tid, tsk.name or 'Unknown') end
  end

  state.palB = createBuf(bufName, 'raz-output', false)
  syntax.apply(state.palB)

  if state.palW and vim.api.nvim_win_is_valid(state.palW) then
    vim.api.nvim_win_set_buf(state.palW, state.palB)
    vim.wo[state.palW].signcolumn = 'no'
  end

  M.palB = state.palB

  return state.palB
end

function M.isValid(winType)
  if winType == 'list' then
    return state.listW and vim.api.nvim_win_is_valid(state.listW)
  elseif winType == 'panel' then
    return state.palW and vim.api.nvim_win_is_valid(state.palW)
  elseif winType == 'keys' then
    return state.keysW and vim.api.nvim_win_is_valid(state.keysW)
  end
  return false
end

function M.isValidBuf(bufType)
  if bufType == 'list' then
    return state.listB and vim.api.nvim_buf_is_valid(state.listB)
  elseif bufType == 'panel' then
    return state.palB and vim.api.nvim_buf_is_valid(state.palB)
  elseif bufType == 'keys' then
    return state.keysB and vim.api.nvim_buf_is_valid(state.keysB)
  end
  return false
end

function M.focus(winType)
  if winType == 'list' and M.isValid('list') then
    vim.api.nvim_set_current_win(state.listW)
    -- Ensure cursor is at column 0 in the list window
    local pos = vim.api.nvim_win_get_cursor(state.listW)
    if pos[2] ~= 0 then vim.api.nvim_win_set_cursor(state.listW, { pos[1], 0 }) end
  elseif winType == 'panel' and M.isValid('panel') then
    vim.api.nvim_set_current_win(state.palW)
  end
end

function M.close()
  if state.keysW and vim.api.nvim_win_is_valid(state.keysW) then vim.api.nvim_win_close(state.keysW, true) end
  if state.palW and vim.api.nvim_win_is_valid(state.palW) then vim.api.nvim_win_close(state.palW, true) end
  if state.listW and vim.api.nvim_win_is_valid(state.listW) then vim.api.nvim_win_close(state.listW, true) end

  state.listW = nil
  state.listB = nil
  state.palW = nil
  state.palB = nil
  state.keysW = nil
  state.keysB = nil

  M.listW = nil
  M.listB = nil
  M.palW = nil
  M.palB = nil
  M.keysW = nil
  M.keysB = nil
end

function M.isOpen() return M.isValid('list') or M.isValid('panel') end

function M.resize()
  if not M.isOpen() then return end

  local cfg = require('exer.ui.config').all()
  local win_height, win_width = calcDims(cfg)
  local rowS, colS, wDtl = calcPos(win_height, win_width)

  if M.isValid('list') then vim.api.nvim_win_set_config(state.listW, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = rowS,
    col = colS,
  }) end

  if M.isValid('panel') then vim.api.nvim_win_set_config(state.palW, {
    relative = 'editor',
    width = wDtl,
    height = win_height,
    row = rowS,
    col = colS + win_width + 3,
  }) end

  if M.isValid('keys') then
    local rowKey = rowS + win_height
    local colKey = colS + 1
    vim.api.nvim_win_set_config(state.keysW, {
      relative = 'editor',
      width = win_width,
      row = rowKey,
      col = colKey,
    })
  end
end

function M.getCurrentTaskWin()
  local currentWin = vim.api.nvim_get_current_win()
  if currentWin == state.listW then
    return 'list'
  elseif currentWin == state.palW then
    return 'panel'
  end
  return nil
end

return M
