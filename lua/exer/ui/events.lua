local M = {}
local co = require('exer.core')
local render = require('exer.ui.render')
local windows = require('exer.ui.windows')

local state = {
  timer = nil,
  autoCmdGrp = nil,
  focusId = nil,
  autoScroll = true,
}

local function focus(taskId)
  if state.focusId ~= taskId then
    state.focusId = taskId
    if taskId and windows.isValid('panel') then
      local curBuf = vim.api.nvim_win_get_buf(windows.palW)
      local bufName = vim.api.nvim_buf_get_name(curBuf)

      if bufName:match('Task Panel') or not windows.isValidBuf('panel') or curBuf ~= windows.palB then
        M.showTaskPanel(taskId)
      else
        render.renderPanel(taskId, state.autoScroll)
      end
    end
  end
end

local function refreshPanel(tid, forceFull)
  if not tid then return end

  if not windows.isValid('panel') then
    local ui = require('exer.ui')
    ui.showList(true)
  end

  if forceFull then
    M.showTaskPanel(tid, true)
  else
    render.renderPanel(tid, state.autoScroll)
  end
end

local function onAutoCmdTsk(args)
  local pattern = args.match or args.pattern

  if pattern == 'RazTaskComplete' then
    if args.data and args.data.tskId == state.focusId then
      local tid = state.focusId
      -- Don't auto-focus on task completion, just update panel content
      vim.defer_fn(function()
        if not windows.isValid('panel') then
          local ui = require('exer.ui')
          ui.showList(true)
        end
        render.renderPanel(tid, state.autoScroll)
      end, 500)
    end
    return
  end

  if not windows.isValidBuf('list') then return end

  vim.schedule(function()
    render.renderList()

    if pattern == 'RazTaskCreated' or pattern == 'RazTaskStarted' then
      if args.data and args.data.tskId then
        local taskId = args.data.tskId
        if pattern == 'RazTaskStarted' then
          state.focusId = taskId
          refreshPanel(taskId, true)
        else
          focus(taskId)
        end
      end
    elseif pattern == 'RazTaskOutput' then
      if args.data and args.data.tskId == state.focusId then render.renderPanel(state.focusId, state.autoScroll) end
    end
  end)
end

local function startUpdTimer()
  if state.timer then state.timer:stop() end

  state.timer = vim.uv.new_timer()

  local cntUpd = 0
  state.timer:start(
    500,
    500,
    vim.schedule_wrap(function()
      if windows.isValidBuf('list') then
        cntUpd = cntUpd + 1

        render.renderList()

        if state.focusId and windows.isValidBuf('panel') then
          local tskSel = co.tsk.get(state.focusId)
          if tskSel then
            if tskSel.status == 'running' then render.renderPanel(state.focusId, state.autoScroll) end
          end
        end
      else
        if state.timer then
          state.timer:stop()
          state.timer = nil
        end
      end
    end)
  )
end

function M.initAutoCmd()
  if state.autoCmdGrp then return end

  state.autoCmdGrp = vim.api.nvim_create_augroup('RazTaskUI', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = state.autoCmdGrp,
    pattern = { 'RazTaskCreated', 'RazTaskStarted', 'RazTaskOutput', 'RazTaskComplete' },
    callback = onAutoCmdTsk,
  })
end

function M.startTimer() startUpdTimer() end

function M.stopTimer()
  if state.timer then
    state.timer:stop()
    state.timer = nil
  end
end

function M.cleanup()
  M.stopTimer()
  if state.autoCmdGrp then
    vim.api.nvim_del_augroup_by_id(state.autoCmdGrp)
    state.autoCmdGrp = nil
  end
end

function M.showTaskPanel(tid, autoFocus)
  state.focusId = tid
  if not windows.isValidBuf('panel') then windows.createPanelBuffer(tid) end
  render.renderPanel(tid, state.autoScroll)
  if autoFocus then windows.focus('panel') end
end

function M.setFocusTask(taskId) focus(taskId) end

function M.getFocusTask() return state.focusId end

function M.toggleAutoScroll()
  state.autoScroll = not state.autoScroll
  return state.autoScroll
end

function M.getAutoScroll() return state.autoScroll end

function M.setAutoScroll(enabled) state.autoScroll = enabled end

function M.clearFocus() state.focusId = nil end

function M.handleClearedTasks()
  if state.focusId then
    local tskSel = co.tsk.get(state.focusId)
    if tskSel and (tskSel.status == 'completed' or tskSel.status == 'failed') then
      state.focusId = nil
      render.renderPlaceholder('Task was cleared')
      windows.focus('list')
    end
  end
end

return M
