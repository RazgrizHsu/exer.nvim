local M = {}
local co = require('exer.core')
local render = require('exer.ui.render')
local events = require('exer.ui.events')
local windows = require('exer.ui.windows')
local config = require('exer.ui.config')

-- Update panel based on current cursor position
local function updatePanelFromCursor(skipFocus)
  local t = render.getSelectedTask()
  if t then
    events.setFocusTask(t.id)
    if not skipFocus then
      events.showTaskPanel(t.id)
      -- For tabs functionality, update active tab when focusing a task
      if events.hasMultipleTabs() then
        local taskTabs = events.getTaskTabs()
        for i, tabTaskId in ipairs(taskTabs) do
          if tabTaskId == t.id then
            events.switchTab(i)
            break
          end
        end
      end
    end
    if windows.isValidBuf('panel') then render.renderPanel(t.id, events.getAutoScroll()) end
  end
  -- if no task is selected, keep current panel state unchanged
end

function M.smartNav(direction)
  local current_win = vim.api.nvim_get_current_win()
  local ui_is_open = windows.isOpen()
  local in_task_ui = ui_is_open and ((current_win == windows.listW) or (current_win == windows.palW))

  if in_task_ui then
    -- Handle internal navigation in task UI
    if direction == 'left' and current_win == windows.palW then
      -- From panel to list
      windows.focus('list')
      return
    elseif direction == 'right' and current_win == windows.listW then
      -- From list to panel
      windows.focus('panel')
      return
    end

    -- For up/down in task UI, try to go back to editor
    local main_wins = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= windows.listW and win ~= windows.palW and vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == '' then -- Regular file buffer
          table.insert(main_wins, win)
        end
      end
    end
    if #main_wins > 0 then
      vim.api.nvim_set_current_win(main_wins[1])
      return
    end
  else
    -- Try standard window command first
    local wincmd_map = {
      up = 'k',
      down = 'j',
      left = 'h',
      right = 'l',
    }

    local cmd = wincmd_map[direction]
    if cmd then
      vim.cmd('wincmd ' .. cmd)
      local new_win = vim.api.nvim_get_current_win()
      if new_win ~= current_win then
        return -- Standard navigation worked
      end

      -- No movement happened, check if tmux-navigator exists
      local tmux_cmds = {
        up = 'TmuxNavigateUp',
        down = 'TmuxNavigateDown',
        left = 'TmuxNavigateLeft',
        right = 'TmuxNavigateRight',
      }

      local tmux_cmd = tmux_cmds[direction]
      if tmux_cmd and vim.fn.exists(':' .. tmux_cmd) == 2 then
        -- Try tmux navigation first
        local ok = pcall(vim.cmd, tmux_cmd)
        if ok then
          -- Check if we actually moved to a different tmux pane
          vim.defer_fn(function()
            local after_tmux_win = vim.api.nvim_get_current_win()
            if after_tmux_win == current_win then
              -- Still in same window, tmux didn't move us, try task UI
              if (direction == 'down' or direction == 'right') and ui_is_open then
                local ui = require('exer.ui')
                ui.focusUI()
              end
            end
          end, 10) -- Small delay to let tmux navigation complete
          return
        end
      end

      -- No tmux or tmux navigation failed, try going to task UI
      if direction == 'down' or direction == 'right' then
        if ui_is_open then
          local ui = require('exer.ui')
          ui.focusUI()
        end
      end
    end
  end
end

function M.setupListKeymaps(buffer)
  local opts = { noremap = true, silent = true, buffer = buffer }

  -- Navigation keys that update panel content
  local function navAndUpdate(key)
    vim.cmd('normal! ' .. key)
    -- Keep cursor at column 0 (first column)
    local pos = vim.api.nvim_win_get_cursor(0)
    if pos[2] ~= 0 then vim.api.nvim_win_set_cursor(0, { pos[1], 0 }) end
    updatePanelFromCursor()
  end

  -- Enter: Focus to task panel (panel content already updated by navigation)
  vim.keymap.set('n', '<CR>', function()
    local t = render.getSelectedTask()
    if t then windows.focus('panel') end
  end, opts)

  -- Navigation keys with panel update
  vim.keymap.set('n', 'j', function() navAndUpdate('j') end, opts)
  vim.keymap.set('n', 'k', function() navAndUpdate('k') end, opts)
  vim.keymap.set('n', '<Down>', function() navAndUpdate('j') end, opts)
  vim.keymap.set('n', '<Up>', function() navAndUpdate('k') end, opts)
  vim.keymap.set('n', 'gg', function() navAndUpdate('gg') end, opts)
  vim.keymap.set('n', 'G', function() navAndUpdate('G') end, opts)

  -- Stop selected task
  vim.keymap.set('n', config.keymaps.stop_task, function()
    local t = render.getSelectedTask()
    if t then
      co.tsk.stop(t.id)
      render.renderList()
      updatePanelFromCursor(true) -- Skip focus change
    end
  end, opts)

  -- Clear completed tasks
  vim.keymap.set('n', config.keymaps.clear_completed, function()
    local tskSel = nil
    local focusId = events.getFocusTask()
    if focusId then tskSel = co.tsk.get(focusId) end

    local cleared_count = co.tsk.clearDones()
    render.renderList()

    -- If selected task was cleared, reset to placeholder
    if tskSel and (tskSel.status == 'completed' or tskSel.status == 'failed') then
      events.clearFocus()
      render.renderPlaceholder(cleared_count > 0 and ('Cleared ' .. cleared_count .. ' completed tasks') or 'No tasks to clear')
    end

    if cleared_count > 0 then co.utils.msg('Cleared ' .. cleared_count .. ' completed tasks') end
  end, opts)

  -- Close UI
  vim.keymap.set('n', config.keymaps.close_ui, function()
    local ui = require('exer.ui')
    ui.close()
  end, opts)

  -- Toggle auto scroll
  vim.keymap.set('n', config.keymaps.toggle_auto_scroll, function()
    local autoScroll = events.toggleAutoScroll()
    co.utils.msg('Auto scroll: ' .. (autoScroll and 'ON' or 'OFF'))
    windows.updateScrollStatus()
  end, opts)

  -- Tab: Switch to panel
  vim.keymap.set('n', '<Tab>', function()
    if windows.isValid('panel') then windows.focus('panel') end
  end, opts)

  -- l: Switch to panel
  vim.keymap.set('n', 'l', function()
    if windows.isValid('panel') then windows.focus('panel') end
  end, opts)

  -- Mouse click: Update panel content
  vim.keymap.set('n', '<LeftMouse>', function()
    -- Use nvim_win_set_cursor instead of normal! command to avoid modifiable issues
    local pos = vim.fn.getmousepos()
    if pos.winid == vim.api.nvim_get_current_win() and pos.line > 0 then
      -- Always set cursor to column 0
      vim.api.nvim_win_set_cursor(0, { pos.line, 0 })
    end
    updatePanelFromCursor()
  end, opts)

  -- Smart navigation
  vim.keymap.set('n', '<C-h>', function() M.smartNav('left') end, opts)
  vim.keymap.set('n', '<C-j>', function() M.smartNav('down') end, opts)
  vim.keymap.set('n', '<C-k>', function() M.smartNav('up') end, opts)
  vim.keymap.set('n', '<C-l>', function() M.smartNav('right') end, opts)
end

function M.setupPanelKeymaps(buffer)
  local opts = { noremap = true, silent = true, buffer = buffer }

  -- Close UI
  vim.keymap.set('n', config.keymaps.close_ui, function()
    local ui = require('exer.ui')
    ui.close()
  end, opts)

  -- Esc: Close UI
  vim.keymap.set('n', '<Esc>', function()
    local ui = require('exer.ui')
    ui.close()
  end, opts)

  -- Stop current task
  vim.keymap.set('n', config.keymaps.stop_task, function()
    local focusId = events.getFocusTask()
    if focusId then
      co.tsk.stop(focusId)
      render.renderList()
      co.utils.msg('Stopped task #' .. focusId)
    end
  end, opts)

  -- Clear completed tasks
  vim.keymap.set('n', config.keymaps.clear_completed, function()
    local t = nil
    local focusId = events.getFocusTask()
    if focusId then t = co.tsk.get(focusId) end

    local cntClr = co.tsk.clearDones()
    render.renderList()

    -- If selected task was cleared, close current panel and show placeholder
    if t and (t.status == 'completed' or t.status == 'failed') then
      events.clearFocus()
      windows.focus('list')
    end

    if cntClr > 0 then
      co.utils.msg('Cleared ' .. cntClr .. ' completed tasks')
    else
      co.utils.msg('No completed tasks to clear')
    end
  end, opts)

  -- Toggle auto scroll
  vim.keymap.set('n', config.keymaps.toggle_auto_scroll, function()
    local autoScroll = events.toggleAutoScroll()
    co.utils.msg('Auto scroll: ' .. (autoScroll and 'ON' or 'OFF'))
    windows.updateScrollStatus()
  end, opts)

  -- Tab: Switch to list
  vim.keymap.set('n', '<Tab>', function()
    if windows.isValid('list') then windows.focus('list') end
  end, opts)

  -- h: Smart left navigation (switch to list only if at leftmost position)
  vim.keymap.set('n', 'h', function()
    local pos = vim.api.nvim_win_get_cursor(0)
    local col = pos[2]

    -- Try to move left first
    if col > 0 then
      vim.cmd('normal! h')
    else
      -- Already at leftmost position, switch to list
      if windows.isValid('list') then windows.focus('list') end
    end
  end, opts)

  -- Tab switching (only when multiple tabs exist)
  for i = 1, 9 do
    vim.keymap.set('n', tostring(i), function()
      if events.hasMultipleTabs() then
        local taskId = events.switchTab(i)
        if taskId then render.renderPanel(taskId, events.getAutoScroll()) end
      end
    end, opts)
  end

  -- Smart navigation
  vim.keymap.set('n', '<C-h>', function() M.smartNav('left') end, opts)
  vim.keymap.set('n', '<C-j>', function() M.smartNav('down') end, opts)
  vim.keymap.set('n', '<C-k>', function() M.smartNav('up') end, opts)
  vim.keymap.set('n', '<C-l>', function() M.smartNav('right') end, opts)
end

function M.setupPlaceholderKeymaps(buffer)
  local opts = { noremap = true, silent = true, buffer = buffer }

  -- Close UI
  vim.keymap.set('n', config.keymaps.close_ui, function()
    local ui = require('exer.ui')
    ui.close()
  end, opts)

  -- Esc: Close UI
  vim.keymap.set('n', '<Esc>', function()
    local ui = require('exer.ui')
    ui.close()
  end, opts)
end

return M
