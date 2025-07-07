local M = {}

local cfgs = require('exer.ui.config')
local wins = require('exer.ui.windows')
local rndr = require('exer.ui.render')
local evts = require('exer.ui.events')
local kmps = require('exer.ui.keymaps')
local co = require('exer.core')

local prevWin = nil

function M.showList(skipFocusList)
  evts.initAutoCmd()

  if wins.isValid('list') then
    rndr.renderList()

    if not skipFocusList then wins.focus('list') end

    local tasks = co.tsk.getAll()
    if #tasks > 0 and not evts.getFocusTask() then evts.setFocusTask(tasks[1].id) end

    return
  end

  if not prevWin then
    prevWin = vim.api.nvim_get_current_win()
  end

  local _, listB, _, palB = wins.createMain(cfgs.all())

  wins.createKeysHelp(cfgs.all())

  kmps.setupListKeymaps(listB)
  kmps.setupPanelKeymaps(palB)

  vim.api.nvim_create_autocmd('VimResized', {
    callback = function() wins.resize() end,
    desc = 'Resize task UI windows on terminal resize',
  })

  wins.focus('list')
  rndr.renderList()

  evts.startTimer()

  if cfgs.auto_toggle then
    local tasks = co.tsk.getAll()
    if #tasks > 0 then evts.setFocusTask(tasks[1].id) end
  end
end

function M.showTskPal(tid, autoFocus)
  autoFocus = autoFocus or false

  if not wins.isValid('panel') then
    M.showList()
    if not wins.isValid('panel') then return end
  end

  wins.createPanelBuffer(tid)

  local palB = wins.palB
  if palB then kmps.setupPanelKeymaps(palB) end

  evts.showTaskPanel(tid, autoFocus)
end

function M.close()
  evts.cleanup()
  wins.close()
  
  if prevWin and vim.api.nvim_win_is_valid(prevWin) then
    vim.api.nvim_set_current_win(prevWin)
  end
  
  prevWin = nil
end

function M.toggle()
  if wins.isOpen() then
    M.close()
    return
  end
  
  prevWin = vim.api.nvim_get_current_win()
  M.showList()
end

function M.setup(opts)
  local cfg = cfgs.setup(opts)
  evts.setAutoScroll(cfg.auto_scroll)
end

function M.focusUI()
  if wins.isOpen() then
    if wins.isValid('list') then
      wins.focus('list')
    elseif wins.isValid('panel') then
      wins.focus('panel')
    end
  else
    M.showList()
  end
end

function M.smartNav(direction) require('exer.ui.keymaps').smartNav(direction) end

M.setup({})

return M
