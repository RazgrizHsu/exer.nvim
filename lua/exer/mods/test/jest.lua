local M = {}

local keys = {
  all = 'jest:all',
  file = 'jest:file',
  cursor = 'jest:cursor',
}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')

local function findJestCfg()
  local fs = {
    'jest.config.ts',
    'jest.config.js',
    'jest.config.json',
  }

  return co.io.findFile(vim.fn.getcwd(), fs)
end

local function parseJestCfg(path)
  if not path then return nil end

  local ext = vim.fn.fnamemodify(path, ':e')

  if ext == 'json' then
    local src = vim.fn.readfile(path)
    local jsonStr = table.concat(src, '\n')
    local ok, cfg = pcall(co.psr.json.decode, jsonStr)
    if ok and cfg.testMatch then return cfg.testMatch end
  elseif ext == 'ts' or ext == 'js' then
    local content = vim.fn.readfile(path)
    local contentStr = table.concat(content, '\n')

    local rgx = 'testMatch:%s*%[%s*(.-)%s*%]'
    local mthStr = contentStr:match(rgx)

    if mthStr then
      local mths = {}
      for match in mthStr:gmatch('"([^"]*)"') do
        table.insert(mths, match)
      end
      for match in mthStr:gmatch("'([^']*)'") do
        table.insert(mths, match)
      end

      if #mths > 0 then
        co.lg.debug('Regex parsed testMatch: ' .. vim.inspect(mths), 'Regex Parse Success')
        return mths
      end
    end

    local cmd = string.format('npx ts-node -e "const cfg = require(\'%s\'); const config = cfg.config || cfg.default || cfg; console.log(JSON.stringify(config.testMatch || null))"', path)
    co.lg.info('Using ts-node fallback...', 'Fallback to ts-node')
    local rst = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
      local cleanRst = rst:gsub('\n', ''):gsub('%s+', '')
      if cleanRst ~= 'null' and cleanRst ~= '' then
        local ok, testMatch = pcall(co.psr.json.decode, cleanRst)
        if ok and testMatch then return testMatch end
      end
    end
  end

  co.lg.warn('Failed to parse Jest config', 'Jest Parse Failed')
  return nil
end

local function isTestFileByCfg(pathF, testMatch)
  if not testMatch or type(testMatch) ~= 'table' then return false end

  local pathAbs = vim.fn.fnamemodify(pathF, ':p')
  local dirRoot = vim.fn.getcwd()

  co.lg.debug('Checking file: ' .. pathAbs, 'File Check')
  co.lg.debug('Root dir: ' .. dirRoot, 'Root Dir')

  for _, pattern in ipairs(testMatch) do
    co.lg.debug('Testing pattern: ' .. pattern, 'Pattern')

    local isNegative = pattern:match('^!')
    local pathRel = pathAbs:gsub('^' .. vim.pesc(dirRoot .. '/'), '')

    co.lg.debug('Relative path: ' .. pathRel, 'Relative')

    if pathRel:match('^tests/') and pathRel:match('%.ts$') and not pathRel:match('%.d%.ts$') then
      co.lg.debug('Match found!', 'Match Success')
      return not isNegative
    end
  end

  return false
end

local function isTestFileByPtn(pathF)
  local nameF = vim.fn.fnamemodify(pathF, ':t')
  local pathDir = vim.fn.fnamemodify(pathF, ':h')

  if nameF:match('%.test%.') or nameF:match('%.spec%.') then return true end
  if pathDir:match('__tests__') then return true end

  return false
end

local function isTestFile(pathF)
  local pathCfg = findJestCfg()

  if pathCfg then
    local testMatch = parseJestCfg(pathCfg)
    if testMatch then return isTestFileByCfg(pathF, testMatch) end
  end

  return isTestFileByPtn(pathF)
end

local function buildCmds(testFile, testName)
  local cmd = 'npx jest'
  cmd = cmd .. ' --verbose'
  cmd = cmd .. ' --detectOpenHandles'
  cmd = cmd .. ' --forceExit'

  if testFile then cmd = cmd .. ' ' .. vim.fn.shellescape(testFile) end
  if testName then cmd = cmd .. ' --testNamePattern=' .. vim.fn.shellescape(testName) end

  return cmd
end

local function buildOpts()
  local env = vim.fn.environ()
  env.FORCE_COLOR = '1'
  env.CI = 'true'
  env.NODE_ENV = 'test'

  return {
    env = env,
    buffedStdOut = false,
    buffedStdErr = false,
    useErrAsOut = true,
  }
end

--========================================================================
-- Detect
--========================================================================
function M.detect(pathWorkDir)
  local jestCfgFs = {
    'jest.config.ts',
    'jest.config.js',
    'jest.config.json',
    'package.json',
  }

  local foundFile = co.io.findFile(pathWorkDir, jestCfgFs)
  if not foundFile then return false end

  local filename = vim.fn.fnamemodify(foundFile, ':t')
  if filename == 'package.json' then
    return co.io.fileContains(foundFile, { '"jest"', '"@jest/' })
  else
    return true
  end
end

--========================================================================
-- Opts
--========================================================================
function M.getOpts(pathWorkDir, pathFile, fileType)
  local opts = require('exer.picker.opts').new()

  if fileType == 'javascript' or fileType == 'typescript' or fileType == 'typescriptreact' or fileType == 'javascriptreact' then
    if isTestFile(pathFile) then
      opts:addTf('Jest: Test at Cursor', keys.cursor, 'jest', 'Jest')
      opts:addTf('Jest: Test Current File', keys.file, 'jest', 'Jest')
    end

    opts:addTf('Jest: Run All Tests', keys.all, 'jest', 'Jest')
  end

  return opts:build()
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(option, pathWorkDir, pathFile)
  if not option or option == '' then
    co.utils.msg('No Jest option specified', vim.log.levels.ERROR)
    return
  end

  local cmd = ''
  local name = ''

  if option == keys.all then
    name = 'Jest: All Tests'
    cmd = buildCmds()
  elseif option == keys.file then
    name = 'Jest: Current File'
    cmd = buildCmds(pathFile)
  elseif option == keys.cursor then
    name = 'Jest: Test at Cursor'
    local tsUtils = co.psr.treesitter
    local testName = tsUtils.getTestNameAtCursor()
    if testName then
      cmd = buildCmds(pathFile, testName)
    else
      cmd = buildCmds(pathFile)
    end
  else
    co.utils.msg('Unknown Jest option: ' .. option, vim.log.levels.ERROR)
    return
  end

  co.runner.run({
    name = name,
    cmds = co.cmd.new():cd(pathWorkDir):add(cmd),
    opts = buildOpts(),
  })
end

return M
