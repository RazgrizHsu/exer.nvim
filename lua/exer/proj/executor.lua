local M = {}
local co = require('exer.core')
local var = require('exer.proj.vars')

local function findActById(actId, allActs)
  for _, act in ipairs(allActs) do
    if act.id == actId then return act end
  end
  return nil
end

local function isActReference(item) return type(item) == 'string' and item:match('^cmd:(.+)$') end

local function getActIdFromReference(item) return item:match('^cmd:(.+)$') end

function M.executeAct(act, allActs)
  local rnr = require('exer.core.runner')
  local actCmd = act.cmd or act.cmds
  local expandedCmd = var.expandVars(actCmd)
  local env = act.env or {}
  local cwd = act.cwd or vim.fn.getcwd()

  if type(expandedCmd) == 'table' then
    if act.cmd then
      -- Sequential execution for cmd array
      M.executeSequential(expandedCmd, act.id, env, cwd, allActs)
    else
      -- Parallel execution for cmds array
      M.executeParallel(expandedCmd, act.id, env, cwd, allActs)
    end
  else
    -- Single command execution
    local taskName = string.format('[proj] %s', act.id)
    rnr.run({ name = taskName, cmd = expandedCmd, env = env, cwd = cwd })
  end
end

function M.executeSequential(cmdList, actId, env, cwd, allActs)
  local rnr = require('exer.core.runner')

  -- Create a single combined command for sequential execution
  local combinedCmd = {}
  for i, item in ipairs(cmdList) do
    if isActReference(item) then
      local refActId = getActIdFromReference(item)
      local refAct = findActById(refActId, allActs)
      if refAct then
        co.lg.debug(string.format('Expanding referenced act: %s', refActId), 'ProjExecutor')
        local refCmd = refAct.cmd or refAct.cmds
        local expandedRefCmd = var.expandVars(refCmd)
        if type(expandedRefCmd) == 'table' then
          for _, c in ipairs(expandedRefCmd) do
            table.insert(combinedCmd, c)
          end
        else
          table.insert(combinedCmd, expandedRefCmd)
        end
      else
        co.lg.warn(string.format('Referenced act not found: %s', refActId), 'ProjExecutor')
      end
    else
      table.insert(combinedCmd, item)
    end
  end

  -- Execute as a single sequential task
  local taskName = string.format('[proj] %s', actId)
  local sequentialCmd = table.concat(combinedCmd, ' && ')
  rnr.run({ name = taskName, cmd = sequentialCmd, env = env, cwd = cwd })
end

function M.executeParallel(cmdList, actId, env, cwd, allActs)
  local rnr = require('exer.core.runner')

  for i, item in ipairs(cmdList) do
    if isActReference(item) then
      local refActId = getActIdFromReference(item)
      local refAct = findActById(refActId, allActs)
      if refAct then
        co.lg.debug(string.format('Executing referenced act: %s', refActId), 'ProjExecutor')
        M.executeAct(refAct, allActs)
      else
        co.lg.warn(string.format('Referenced act not found: %s', refActId), 'ProjExecutor')
      end
    else
      local taskName = string.format('[proj] %s (%d/%d)', actId, i, #cmdList)

      -- Debug: show actual cmd being executed
      -- vim.notify(string.format('Parallel Task %d: cmd="%s" (type: %s)', i, tostring(item), type(item)), vim.log.levels.INFO)

      rnr.run({ name = taskName, cmd = item, env = env, cwd = cwd })
    end
  end
end

return M
