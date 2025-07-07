local M = {}

local state = require('exer.picker.state')
local render = require('exer.picker.render')
local filter = require('exer.picker.filter')
local window = require('exer.picker.window')

function M.getSelected()
  local ste = state.ste
  local currentValidIdx = 0
  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value ~= 'separator' then
      currentValidIdx = currentValidIdx + 1
      if currentValidIdx == ste.selectedIdx then return opt end
    end
  end
  return nil
end

local function navUp()
  local ste = state.ste
  if ste.selectedIdx > 1 then
    ste.selectedIdx = ste.selectedIdx - 1
    render.renderPicker()
  end
end

local function navDown()
  local ste = state.ste
  local validCount = 0
  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value ~= 'separator' then validCount = validCount + 1 end
  end
  if ste.selectedIdx < validCount then
    ste.selectedIdx = ste.selectedIdx + 1
    render.renderPicker()
  end
end

local function navConfirm()
  local selected = M.getSelected()
  local onConfirm = state.ste.onConfirm
  M.navClose()
  vim.cmd('stopinsert')
  if selected and onConfirm then onConfirm(selected) end
end

function M.navClose()
  window.closeWindows(state.ste.listWin, state.ste.inputWin)
  state.reset()
  vim.cmd('stopinsert')
  pcall(vim.api.nvim_del_augroup_by_name, 'raz-picker-auto-close')
end

function M.setKeymaps()
  local ste = state.ste
  local optsInput = { noremap = true, silent = true, buffer = ste.inputBuf }
  local optsList = { noremap = true, silent = true, buffer = ste.listBuf }

  vim.keymap.set('n', 'i', function() vim.cmd('startinsert') end, optsInput)
  vim.keymap.set('n', 'a', function() vim.cmd('startinsert!') end, optsInput)

  vim.keymap.set('i', '<BS>', function()
    if #ste.query > 0 then
      ste.query = ste.query:sub(1, -2)
      filter.filterOpts()
      render.renderPicker()
    end
  end, optsInput)

  for i = 32, 126 do
    local char = string.char(i)
    vim.keymap.set('i', char, function()
      ste.query = ste.query .. char
      filter.filterOpts()
      render.renderPicker()
    end, optsInput)
  end

  for _, mode in ipairs({ 'n', 'i' }) do
    vim.keymap.set(mode, '<C-j>', navDown, optsInput)
    vim.keymap.set(mode, '<C-k>', navUp, optsInput)
    vim.keymap.set(mode, '<C-l>', navDown, optsInput)
    vim.keymap.set(mode, '<C-h>', navUp, optsInput)
    vim.keymap.set(mode, '<Down>', navDown, optsInput)
    vim.keymap.set(mode, '<Up>', navUp, optsInput)
    vim.keymap.set(mode, '<CR>', navConfirm, optsInput)
    vim.keymap.set(mode, '<Esc>', M.navClose, optsInput)
  end

  vim.keymap.set('n', 'j', navDown, optsList)
  vim.keymap.set('n', 'k', navUp, optsList)
  vim.keymap.set('n', '<Down>', navDown, optsList)
  vim.keymap.set('n', '<Up>', navUp, optsList)
  vim.keymap.set('n', '<CR>', navConfirm, optsList)
  vim.keymap.set('n', '<Esc>', M.navClose, optsList)
  vim.keymap.set('n', 'q', M.navClose, optsList)
end

function M.setupAutoClose()
  local ste = state.ste
  local augroup = vim.api.nvim_create_augroup('raz-picker-auto-close', { clear = true })

  local function onLeave()
    vim.schedule(function()
      local curWin = vim.api.nvim_get_current_win()
      local listValid = state.isListWinValid()
      local inputValid = state.isInputWinValid()

      if not listValid and not inputValid then return end

      local isPickerWin = (listValid and curWin == ste.listWin) or (inputValid and curWin == ste.inputWin)

      if not isPickerWin then M.navClose() end
    end)
  end

  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = ste.listBuf,
    group = augroup,
    callback = onLeave,
  })

  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = ste.inputBuf,
    group = augroup,
    callback = onLeave,
  })
end

return M
