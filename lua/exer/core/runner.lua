local M = {}
local task = require('exer.core.tsk')
local utils = require('exer.core.utils')

local defaults = {
  showUI = true,
  autoScroll = true,
}

function M.run(config)
  local cfg = vim.tbl_extend('force', defaults, config)

  if cfg.cmds then
    cfg.cmd = cfg.cmds:build()
    -- Extract cwd from cmds if not already set
    if not cfg.cwd and cfg.cmds.cwd then cfg.cwd = cfg.cmds.cwd end
  end

  local taskCfg = {
    cmd = cfg.cmd,
    name = cfg.name,
    cwd = cfg.cwd,
    env = cfg.env,
    strategy = cfg.strategy or 'jobstart',
  }

  if cfg.opts then taskCfg = vim.tbl_extend('force', taskCfg, cfg.opts) end

  -- Prepare opts for task.mk - include cwd and env for jobstart
  local taskOpts = cfg.opts or {}
  if cfg.cwd then taskOpts.cwd = cfg.cwd end
  if cfg.env and next(cfg.env) then taskOpts.env = cfg.env end -- Only set env if it's not empty

  local t = task.mk(cfg.name, cfg.cmd, taskOpts)
  task.run(t.id)

  if cfg.showUI then require('exer.ui').showList() end

  return t
end

function M.batch(tasks)
  local results = {}
  for _, taskCfg in ipairs(tasks) do
    table.insert(results, M.run(taskCfg))
  end
  return results
end

function M.sync(config)
  config.strategy = 'jobwait'
  return M.run(config)
end

function M.withUI(config, uiConfig)
  local t = M.run(config)

  if uiConfig then require('exer.ui').show(t.id, uiConfig) end

  return t
end

---Run a function with validated paths
---@param pathSpecs table<string, string|table> Path specifications
---@param fn function Function to run with validated paths
function M.runWithPaths(pathSpecs, fn)
  local paths = {}
  for key, spec in pairs(pathSpecs) do
    if type(spec) == 'string' then spec = { path = spec } end

    local path = utils.osPath(spec.path, spec.surround)
    if not path then
      utils.msg(string.format('%s not found: %s', spec.desc or key, spec.path), vim.log.levels.ERROR)
      return
    end
    paths[key] = path
  end

  local ok, err = pcall(fn, paths)
  if not ok then
    if err ~= 'guard' then -- 排除 guard 錯誤（已處理）
      utils.msg('Execution error: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M
