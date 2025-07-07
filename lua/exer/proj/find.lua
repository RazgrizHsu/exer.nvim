local M = {}
local co = require('exer.core')

local function checkEmbedCfg(filePath, sec)
  if not co.io.fileExists(filePath) then return nil end

  local cnt = vim.fn.readfile(filePath)
  if not cnt or #cnt == 0 then return nil end

  local fileCnt = table.concat(cnt, '\n')

  if filePath:match('%.toml$') then
    local secPat = '%[' .. sec:gsub('%.', '%%.') .. '%]'
    local secStart = fileCnt:find(secPat)
    if secStart then
      local secEnd = fileCnt:find('\n%[', secStart + 1)
      local secCnt = fileCnt:sub(secStart, secEnd and secEnd - 1 or -1)

      if secCnt:match('acts%s*=') then return filePath end
    end
  elseif filePath:match('package%.json$') then
    local ok, json = pcall(vim.fn.json_decode, fileCnt)
    if ok and json and json.exec then return filePath end
  end

  return nil
end

function M.find()
  local rt = co.io.getRoot()

  local cfgFs = {
    { path = rt .. '/proj.toml' },
    { path = rt .. '/exec.toml' },
    { path = rt .. '/.exec.toml' },
    { path = rt .. '/.exec' },
    { path = rt .. '/pyproject.toml', sec = 'tool.exec' },
    { path = rt .. '/Cargo.toml', sec = 'package.metadata.exec' },
    { path = rt .. '/package.json', sec = 'exec' },
  }

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

  if fname == 'exec.toml' or fname == '.exec.toml' or fname == '.exec' then
    return 'standalone'
  elseif fname == 'pyproject.toml' or fname == 'Cargo.toml' or fname == 'package.json' then
    return 'embedded'
  end

  return 'standalone'
end

return M
