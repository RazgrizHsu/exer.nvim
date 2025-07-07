local M = {}

local psr = require('exer.proj.parser')
local fnd = require('exer.proj.find')
local vad = require('exer.proj.valid')
local cpr = require('exer.proj.compiler')
local tsk = require('exer.proj.tasks')
local var = require('exer.proj.vars')

local cache = {}

function M.load()
  local cfgPath = M.findCfg()
  if not cfgPath then return { acts = {}, apps = {} } end

  if cache[cfgPath] then return cache[cfgPath] end

  local cnt = vim.fn.readfile(cfgPath)
  if not cnt or #cnt == 0 then return { acts = {}, apps = {} } end

  local tomlCnt = table.concat(cnt, '\n')
  local cfg = M.parse(tomlCnt)

  if not cfg then return { acts = {}, apps = {} } end

  if not M.validate(cfg) then return { acts = {}, apps = {} } end

  cache[cfgPath] = cfg
  return cfg
end

function M.findCfg() return fnd.find() end

function M.parse(cnt) return psr.parse(cnt) end

function M.filterActs(acts, ft)
  if not acts or #acts == 0 then return {} end

  local flt = {}
  for _, act in ipairs(acts) do
    if not act.when then
      table.insert(flt, act)
    elseif type(act.when) == 'string' then
      if act.when == ft then table.insert(flt, act) end
    elseif type(act.when) == 'table' then
      for _, whenFt in ipairs(act.when) do
        if whenFt == ft then
          table.insert(flt, act)
          break
        end
      end
    end
  end

  return flt
end

function M.expandVars(cmd) return var.expandVars(cmd) end

function M.validate(cfg) return vad.validate(cfg) end

function M.inferType(entry) return cpr.inferType(entry) end

function M.inferLang(entry) return cpr.inferLang(entry) end

function M.findCompileFiles(entry, pattern) return tsk.findCompileFiles(entry, pattern) end

function M.generateBuildTask(app, lang) return tsk.generateBuildTask(app, lang) end

function M.generateRunTask(app) return tsk.generateRunTask(app) end

function M.generateBuildAndRunTask(app, lang) return tsk.generateBuildAndRunTask(app, lang) end

function M.processApps(apps, ft) return tsk.processApps(apps, ft) end

function M.getActs(ft)
  local cfg = M.load()
  if not cfg then return {} end

  local acts = {}

  -- Add original acts
  if cfg.acts then
    local filteredActs = M.filterActs(cfg.acts, ft)
    vim.list_extend(acts, filteredActs)
  end

  -- Process apps, convert to acts
  if cfg.apps then
    local appActs = tsk.processApps(cfg.apps, ft)
    vim.list_extend(acts, appActs)
  end

  return acts
end

function M.clearCache() cache = {} end

return M
