local M = {}
local log = require('exer.core.lg')

local function getNowMs() return os.time() * 1000 + math.floor((vim.uv.hrtime() % 1e9) / 1e6) end

local tsks = {}
local cntTsk = 0

local STATUS = {
  PENDING = 'pending',
  RUNNING = 'running',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

function M.mk(name, cmd, optsJob)
  cntTsk = cntTsk + 1
  local t = {
    id = cntTsk,
    name = name,
    cmd = cmd,
    status = STATUS.PENDING,
    output = {},
    startTime = nil,
    endTime = nil,
    exitCode = nil,
    jobId = nil,
    opts = optsJob or {},
    cwd = optsJob and optsJob.cwd or vim.fn.getcwd(),
    stderrIsOutput = optsJob and optsJob.useErrAsOut or false, -- some tools use stderr as normal output
  }
  tsks[t.id] = t
  -- log.info('Created task #' .. t.id .. ': ' .. name, 'Task')

  -- notify UI that task has been created
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'RazTaskCreated',
    data = { tskId = t.id, task = t },
  })

  return t
end

-- start task
function M.run(tid)
  local tsk = tsks[tid]
  if not tsk then
    log.error('Task not found: ' .. tid, 'Task')
    return false
  end

  if tsk.status == STATUS.RUNNING then
    log.warn('Task already running: ' .. tsk.name, 'Task')
    return false
  end

  tsk.status = STATUS.RUNNING
  tsk.startTime = getNowMs()
  tsk.output = {}

  vim.api.nvim_exec_autocmds('User', {
    pattern = 'RazTaskStarted',
    data = { tskId = tid, task = tsk },
  })

  -- execute command (allow external execution options)
  local optsJob = tsk.opts or {}
  optsJob.buffedStdOut = optsJob.buffedStdOut or false
  optsJob.buffedStdErr = optsJob.buffedStdErr or false

  -- Validate cwd if provided
  if optsJob.cwd then
    local cwdPath = vim.fn.expand(optsJob.cwd)
    if vim.fn.isdirectory(cwdPath) ~= 1 then
      tsk.status = STATUS.FAILED
      tsk.endTime = getNowMs()
      table.insert(tsk.output, string.format('Error: Working directory does not exist: %s', optsJob.cwd))
      log.error(string.format('Task #%d failed: Working directory does not exist: %s', tid, optsJob.cwd), 'Task')
      vim.api.nvim_exec_autocmds('User', { pattern = 'RazTaskComplete', data = { tskId = tid, success = false } })
      return false
    end
    -- Update to expanded path
    optsJob.cwd = cwdPath
  end

  tsk.jobId = vim.fn.jobstart(
    tsk.cmd,
    vim.tbl_extend('force', optsJob, {
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= '' then table.insert(tsk.output, line) end
          end
          vim.api.nvim_exec_autocmds('User', { pattern = 'RazTaskOutput', data = { tskId = tid } })
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= '' then
              if tsk.stderrIsOutput then
                -- some tools (like Jest) use stderr as normal output
                table.insert(tsk.output, line)
              else
                table.insert(tsk.output, '  ' .. line)
              end
            end
          end
          vim.api.nvim_exec_autocmds('User', { pattern = 'RazTaskOutput', data = { tskId = tid } })
        end
      end,
      on_exit = function(_, excod)
        tsk.endTime = getNowMs()
        tsk.exitCode = excod
        tsk.status = excod == 0 and STATUS.COMPLETED or STATUS.FAILED
        tsk.jobId = nil

        vim.api.nvim_exec_autocmds('User', { pattern = 'RazTaskComplete', data = { tskId = tid, success = excod == 0 } })

        local dur = (tsk.endTime - tsk.startTime) / 1000
        if excod == 0 then
          log.info(string.format('Task #%d %s (duration: %.3fs)', tid, tsk.status, dur), 'Task')
        else
          log.info(string.format('Task #%d %s (exit: %d, duration: %.3fs)', tid, tsk.status, excod, dur), 'Task')
        end
      end,
    })
  )

  if tsk.jobId == 0 or tsk.jobId == -1 then
    tsk.status = STATUS.FAILED
    tsk.endTime = getNowMs()
    log.error('Failed to start task: ' .. tsk.name, 'Task')
    return false
  end

  log.info('Started task #' .. tid .. ': ' .. tsk.name, 'Task')
  return true
end

-- stop task
function M.stop(tid)
  local tsk = tsks[tid]
  if not tsk or tsk.status ~= STATUS.RUNNING then return false end

  if tsk.jobId then
    vim.fn.jobstop(tsk.jobId)
    tsk.status = STATUS.FAILED
    tsk.endTime = getNowMs()
    table.insert(tsk.output, '[STOPPED BY USER]')
    log.info('Stopped task #' .. tid, 'Task')
    return true
  end
  return false
end

function M.stopAll()
  local stopped = 0
  for id, tsk in pairs(tsks) do
    if tsk.status == STATUS.RUNNING and M.stop(id) then stopped = stopped + 1 end
  end
  return stopped
end

function M.getAll()
  local rst = {}
  for _, tsk in pairs(tsks) do
    table.insert(rst, tsk)
  end
  table.sort(rst, function(a, b) return a.id > b.id end)
  return rst
end

function M.getOutput(tid)
  local tsk = tsks[tid]
  if not tsk then return nil end
  return tsk.output
end

function M.get(tid) return tsks[tid] end

function M.clearDones()
  local cleared = 0
  for id, tsk in pairs(tsks) do
    if tsk.status == STATUS.COMPLETED or tsk.status == STATUS.FAILED then
      tsks[id] = nil
      cleared = cleared + 1
    end
  end
  log.info('Cleared ' .. cleared .. ' completed tasks', 'Task')
  return cleared
end

function M.cntRunning()
  local count = 0
  for _, tsk in pairs(tsks) do
    if tsk.status == STATUS.RUNNING then count = count + 1 end
  end
  return count
end

return M
