local vmd = vim.api.nvim_create_user_command
local co = require('exer.core')
local M = {}

M.setup = function(opts)
  local config = require('exer.config')
  config.setup(opts)

  local cfg = config.get()

  if cfg.debug then
    co.log.logToFile = true
    co.log.info('=== EXER DEBUG MODE ENABLED ===', 'Setup')
    co.log.info('Log file: ' .. co.log.logFile, 'Setup')
    co.log.debug('Global debug flag set: ' .. tostring(_G.g_exer_debug), 'Setup')
  end

  vmd('ExerOpen', function() co.picker.show() end, { desc = 'Open the exer' })

  vmd('ExerShow', function() require('exer.ui').toggle() end, { desc = 'Toggle the exer results' })
  vmd('ExerFocusUI', function() require('exer.ui').focusUI() end, { desc = 'Focus task UI' })
  vmd('ExerNavDown', function() require('exer.ui').smartNav('down') end, { desc = 'Smart navigate down' })
  vmd('ExerNavUp', function() require('exer.ui').smartNav('up') end, { desc = 'Smart navigate up' })
  vmd('ExerNavLeft', function() require('exer.ui').smartNav('left') end, { desc = 'Smart navigate left' })
  vmd('ExerNavRight', function() require('exer.ui').smartNav('right') end, { desc = 'Smart navigate right' })

  vmd('ExerStop', function()
    local stopped = co.tsk.stopAll()
    co.utils.msg(string.format('Stopped %d running task(s).', stopped), vim.log.levels.INFO)
  end, { desc = 'Stop all running tasks' })

  vmd('ExerRedo', function()
    local all_tasks = co.tsk.getAll()
    if #all_tasks == 0 then
      co.utils.msg('No previous task found.', vim.log.levels.INFO)
      return
    end

    local lastT = all_tasks[1]
    co.runner.run({
      name = lastT.name,
      cmd = lastT.cmd,
      opts = lastT.optsJob,
    })
  end, { desc = 'Redo the last task' })
end

return M
