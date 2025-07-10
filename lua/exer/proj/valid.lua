local M = {}

local utils = require('exer.core.utils')

local VALID_APP_TYPES = {
  binary = true,
  class = true,
  jar = true,
  script = true,
}

local function isValidId(id) return type(id) == 'string' and id:match('^[a-zA-Z][a-zA-Z0-9_-]*$') end

local function isValidName(name) return type(name) == 'string' and name ~= '' end

local function isValidCmd(cmd)
  if type(cmd) == 'string' then
    return cmd ~= ''
  elseif type(cmd) == 'table' then
    if #cmd == 0 then return false end
    for _, c in ipairs(cmd) do
      if type(c) ~= 'string' or c == '' then return false end
    end
    return true
  end
  return false
end

local function isValidWhen(when)
  if not when then return true end

  if type(when) == 'string' then
    return when ~= ''
  elseif type(when) == 'table' then
    if #when == 0 then return false end
    for _, w in ipairs(when) do
      if type(w) ~= 'string' or w == '' then return false end
    end
    return true
  end

  return false
end

local function isValidEnv(env)
  if not env then return true end

  if type(env) ~= 'table' then return false end

  for k, v in pairs(env) do
    if type(k) ~= 'string' or k == '' then return false end
    if type(v) ~= 'string' then return false end
  end

  return true
end

local function isValidFiles(files)
  if not files then return true end

  if type(files) == 'string' then
    return files ~= ''
  elseif type(files) == 'table' then
    if #files == 0 then return false end
    for _, f in ipairs(files) do
      if type(f) ~= 'string' or f == '' then return false end
    end
    return true
  end

  return false
end

local function isValidArgs(args)
  if not args then return true end

  if type(args) ~= 'table' then return false end

  for _, arg in ipairs(args) do
    if type(arg) ~= 'string' then return false end
  end

  return true
end

local function validateAct(act)
  if type(act) ~= 'table' then return false, 'act must be a table' end

  -- acts use id and cmd fields
  if not act.id and not act.name then return false, 'act.id or act.name is required' end

  if act.id and not isValidId(act.id) then return false, 'act.id must be a valid identifier' end

  if act.name and not isValidName(act.name) then return false, 'act.name must be a non-empty string' end

  if not act.cmd and not act.cmds then return false, 'act.cmd or act.cmds is required' end

  if act.cmd and not isValidCmd(act.cmd) then return false, 'act.cmd must be a non-empty string or array of strings' end

  if act.cmds and not isValidCmd(act.cmds) then return false, 'act.cmds must be a non-empty string or array of strings' end

  if act.desc and type(act.desc) ~= 'string' then return false, 'act.desc must be a string' end

  if not isValidWhen(act.when) then return false, 'act.when must be a string or array of strings' end

  if not isValidEnv(act.env) then return false, 'act.env must be a table with string keys and values' end

  if act.cwd and type(act.cwd) ~= 'string' then return false, 'act.cwd must be a string' end

  return true
end

local function validateApp(app)
  if type(app) ~= 'table' then return false, 'app must be a table' end

  -- Required fields
  if not app.name then return false, 'app.name is required' end

  if not isValidName(app.name) then return false, 'app.name must be a non-empty string' end

  if not app.entry then return false, 'app.entry is required' end

  if type(app.entry) ~= 'string' or app.entry == '' then return false, 'app.entry must be a non-empty string' end

  if not app.output then return false, 'app.output is required' end

  if type(app.output) ~= 'string' or app.output == '' then return false, 'app.output must be a non-empty string' end

  -- Optional but validated fields
  if app.type then
    if type(app.type) ~= 'string' or not VALID_APP_TYPES[app.type] then return false, 'app.type must be one of: binary, class, jar, script' end
  end

  if not isValidFiles(app.files) then return false, 'app.files must be a string or array of strings' end

  if not isValidArgs(app.build_args) then return false, 'app.build_args must be an array of strings' end

  if not isValidArgs(app.run_args) then return false, 'app.run_args must be an array of strings' end

  if not isValidEnv(app.env) then return false, 'app.env must be a table with string keys and values' end

  if app.cwd and type(app.cwd) ~= 'string' then return false, 'app.cwd must be a string' end

  return true
end

function M.validate(cfg)
  if type(cfg) ~= 'table' then
    utils.msg('proj config must be a table', vim.log.levels.ERROR)
    return false
  end

  -- Validate acts
  if cfg.acts then
    if type(cfg.acts) ~= 'table' then
      utils.msg('proj config.acts must be a table', vim.log.levels.ERROR)
      return false
    end

    local actIds = {}
    local dupCount = {}
    for i, act in ipairs(cfg.acts) do
      local ok, err = validateAct(act)
      if not ok then
        utils.msg(string.format('proj config.acts[%d]: %s', i, err), vim.log.levels.ERROR)
        return false
      end

      local origId = act.id or act.name
      if actIds[origId] then
        dupCount[origId] = (dupCount[origId] or 1) + 1
        local newId = origId .. '_' .. dupCount[origId]

        utils.msg(string.format('proj config.acts[%d]: duplicate id/name "%s", auto-renamed to "%s"', i, origId, newId), vim.log.levels.WARN)

        if act.id then
          act.id = newId
        else
          act.name = newId
        end
        actIds[newId] = true
      else
        dupCount[origId] = 0
        actIds[origId] = true
      end
    end
  end

  -- Validate apps and remove invalid entries
  if cfg.apps then
    if type(cfg.apps) ~= 'table' then
      utils.msg('proj config.apps must be a table', vim.log.levels.ERROR)
      return false
    end

    local validApps = {}
    local appNames = {}
    local invalidDtls = {}

    for i, app in ipairs(cfg.apps) do
      local ok, err = validateApp(app)
      if not ok then
        local appName = app and app.name or string.format('app[%d]', i)
        table.insert(invalidDtls, string.format('%s: %s', appName, err))
        utils.msg(string.format('proj config.apps[%d] "%s": %s', i, appName, err), vim.log.levels.WARN)
      else
        if appNames[app.name] then
          table.insert(invalidDtls, string.format('%s: duplicate name', app.name))
          utils.msg(string.format('proj config.apps[%d]: duplicate name "%s"', i, app.name), vim.log.levels.WARN)
        else
          appNames[app.name] = true
          table.insert(validApps, app)
        end
      end
    end

    if #invalidDtls > 0 then utils.msg(string.format('Skipped %d invalid app configurations:\n%s', #invalidDtls, table.concat(invalidDtls, '\n')), vim.log.levels.INFO) end

    cfg.apps = validApps
  end

  -- Must have at least one acts or apps
  if (not cfg.acts or #cfg.acts == 0) and (not cfg.apps or #cfg.apps == 0) then
    utils.msg('proj config must have at least one valid act or app', vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
