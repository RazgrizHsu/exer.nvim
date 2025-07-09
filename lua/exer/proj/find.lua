local M = {}
local co = require('exer.core')

local function checkEmbedCfg(filePath, sec)
  if not co.io.fileExists(filePath) then
    co.log.debug('[find] File does not exist: ' .. filePath)
    return nil
  end

  local cnt = vim.fn.readfile(filePath)
  if not cnt or #cnt == 0 then
    co.log.debug('[find] File is empty: ' .. filePath)
    return nil
  end

  local fileCnt = table.concat(cnt, '\n')
  co.log.debug('[find] Checking embedded config in: ' .. filePath)

  if filePath:match('%.toml$') then
    local secPat = '%[' .. sec:gsub('%.', '%%.') .. '%]'
    local secStart = fileCnt:find(secPat)
    if secStart then
      local secEnd = fileCnt:find('\n%[', secStart + 1)
      local secCnt = fileCnt:sub(secStart, secEnd and secEnd - 1 or -1)

      if secCnt:match('acts%s*=') then return filePath end
    end
  elseif filePath:match('%.editorconfig$') then
    -- Check for [exer], [exer.acts], or [[exer.acts]] sections
    co.log.debug('[find] Checking .editorconfig content')
    if fileCnt:match('%[exer%]') or fileCnt:match('%[exer%.acts%]') or fileCnt:match('%[%[exer%.acts%]%]') then
      co.log.debug('[find] Found exer section in .editorconfig')
      return filePath
    else
      co.log.debug('[find] No exer section found in .editorconfig')
    end
  elseif filePath:match('package%.json$') then
    local ok, json = pcall(vim.fn.json_decode, fileCnt)
    if ok and json and json.exec then return filePath end
  elseif filePath:match('%.json$') then
    local ok, json = pcall(vim.fn.json_decode, fileCnt)
    if ok and json and (json.exer or json.acts or json.apps) then return filePath end
  end

  return nil
end

local function getDefaultCfgFiles(rt)
  return {
    { path = rt .. '/proj.toml' },
    { path = rt .. '/proj.', sec = 'exer' },
    { path = rt .. '/exer.toml' },
    { path = rt .. '/exer.json', sec = 'exer' },
    { path = rt .. '/.exer.toml' },
    { path = rt .. '/.exer.json', sec = 'exer' },
    { path = rt .. '/.exer' },
    { path = rt .. '/.editorconfig', sec = 'exer' },
    { path = rt .. '/pyproject.toml', sec = 'tool.exer' },
    { path = rt .. '/Cargo.toml', sec = 'package.metadata.exer' },
    { path = rt .. '/package.json', sec = 'exer' },
  }
end

local function getUserCfgFiles(rt, userCfgs)
  local cfgFs = {}

  for _, cfg in ipairs(userCfgs) do
    if type(cfg) == 'string' then
      local path = cfg:sub(1, 1) == '/' and cfg or rt .. '/' .. cfg
      table.insert(cfgFs, { path = path })
    elseif type(cfg) == 'table' and cfg.path then
      local path = cfg.path:sub(1, 1) == '/' and cfg.path or rt .. '/' .. cfg.path
      table.insert(cfgFs, { path = path, sec = cfg.section })
    end
  end

  return cfgFs
end

function M.find()
  local rt = co.io.getRoot()
  local config = require('exer.config')
  local opts = config.get()

  local cfgFs
  if opts.config_files and type(opts.config_files) == 'table' then
    cfgFs = getUserCfgFiles(rt, opts.config_files)
  else
    cfgFs = getDefaultCfgFiles(rt)
  end

  for _, cfg in ipairs(cfgFs) do
    if cfg.sec then
      local fnd = checkEmbedCfg(cfg.path, cfg.sec)
      if fnd then return fnd end
    else
      if co.io.fileExists(cfg.path) then return cfg.path end
    end
  end

  return nil
end

function M.getCfgType(filePath)
  if not filePath then return 'standalone' end

  local fname = vim.fn.fnamemodify(filePath, ':t')

  if fname == 'exer.toml' or fname == '.exer.toml' or fname == '.exer' or fname == 'proj.toml' or fname == 'exer.json' or fname == '.exer.json' then
    return 'standalone'
  elseif fname == 'pyproject.toml' or fname == 'Cargo.toml' or fname == 'package.json' or fname == '.editorconfig' then
    return 'embedded'
  end

  return 'standalone'
end

return M
