local M = {}

local Keys = {
  runFile = 'py:runFile',
  runModule = 'py:runModule',
  runTest = 'py:runTest',
}

--========================================================================
-- public define
--========================================================================
-- Language modules use fileTypes instead of detect() for matching
M.fileTypes = { 'python' }

-- Compiler configurations for different app types and profiles
M.compiler = {
  binary = {
    default = nil, -- Python doesn't compile to binary by default
    pyinstaller = 'pyinstaller ${files} --onefile --distpath "${output}"',
    nuitka = 'python -m nuitka ${files} --onefile --output-dir="${output}"',
    cython = 'cython ${files} -o "${output}.c" && gcc "${output}.c" -o "${output}"',
  },
  module = {
    default = nil, -- Python modules don't need compilation
    bytecode = 'python -m py_compile ${files}',
  },
  script = {
    default = nil, -- Python scripts are interpreted
  },
}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')

--========================================================================
-- Opts
--========================================================================
function M.getOpts(pathWorkDir, pathFile, fileType)
  local opts = require('exer.picker.opts').new()

  if pathFile and pathFile:match('%.py$') then
    opts:addMod('Run file', Keys.runFile, 'python')

    -- Check if it's a test file
    if pathFile:match('test_.*%.py$') or pathFile:match('.*_test%.py$') then opts:addMod('Run tests', Keys.runTest, 'python') end
  end

  -- Check for __main__.py to run as module
  if co.io.fileExists(pathWorkDir .. '/__main__.py') then opts:addMod('Run as module', Keys.runModule, 'python') end

  return opts:build()
end

--========================================================================
-- Compiler Interface
--========================================================================
function M.getCompileCmd(appType, profile)
  profile = profile or 'default'
  local cmds = M.compiler[appType]
  return cmds and cmds[profile]
end

function M.getRunCmd(appType, output)
  if appType == 'script' or appType == 'module' then
    return 'python "${file}"'
  elseif appType == 'binary' then
    return '"${output}"'
  end
  return nil
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(dst, pathWorkDir, pathFile)
  local filename = vim.fn.fnamemodify(pathFile, ':t')

  if dst == Keys.runFile then
    co.runner.run({
      name = 'Run "' .. filename .. '"',
      cmds = co.cmd.new():add('python "' .. pathFile .. '"'),
    })
  elseif dst == Keys.runModule then
    co.runner.run({
      name = 'Run module',
      cmds = co.cmd.new():cd(pathWorkDir):add('python -m .'),
    })
  elseif dst == Keys.runTest then
    co.runner.run({
      name = 'Run tests in "' .. filename .. '"',
      cmds = co.cmd.new():add('python -m pytest "' .. pathFile .. '" -v'),
    })
  end
end

return M
