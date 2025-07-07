local M = {}

local Keys = {
  compileFile = 'c:compileFile',
  compileAndRun = 'c:compileAndRun',
  runFile = 'c:runFile',
}

--========================================================================
-- public define
--========================================================================
-- Language modules use fileTypes instead of detect() for matching
M.fileTypes = { 'c' }

-- Compiler configurations for different app types and profiles
M.compiler = {
  binary = {
    default = 'gcc ${files} -o "${output}" ${args}',
    debug = 'gcc ${files} -g -O0 -o "${output}" ${args}',
    release = 'gcc ${files} -O3 -o "${output}" ${args}',
    clang = 'clang ${files} -o "${output}" ${args}',
    clang_debug = 'clang ${files} -g -O0 -o "${output}" ${args}',
    clang_release = 'clang ${files} -O3 -o "${output}" ${args}',
  },
  library = {
    default = 'gcc -c ${files} -o "${output}.o" ${args}',
    shared = 'gcc -shared -fPIC ${files} -o "${output}.so" ${args}',
    static = 'ar rcs "${output}.a" ${files}',
  },
  script = {
    default = nil, -- C is not a scripting language
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

  if pathFile and pathFile:match('%.c$') then
    opts:addLang('Compile file', Keys.compileFile, 'c', 'C')
    opts:addLang('Compile and run', Keys.compileAndRun, 'c', 'C')

    local execPath = pathFile:gsub('%.c$', '')
    if co.io.fileExists(execPath) then opts:addLang('Run compiled file', Keys.runFile, 'c', 'C') end
  end

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
  if appType == 'binary' then return '"${output}"' end
  return nil
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(dst, pathWorkDir, pathFile)
  local filename = vim.fn.fnamemodify(pathFile, ':t')
  local nameNoExt = vim.fn.fnamemodify(pathFile, ':t:r')
  local fullPathNoExt = vim.fn.fnamemodify(pathFile, ':p:r')

  if dst == Keys.compileFile then
    co.runner.run({
      name = 'Compile "' .. filename .. '"',
      cmds = co.cmd.new():add('gcc "' .. pathFile .. '" -o "' .. fullPathNoExt .. '"'),
    })
  elseif dst == Keys.compileAndRun then
    co.runner.run({
      name = 'Compile and run "' .. filename .. '"',
      cmds = co.cmd.new():add('gcc "' .. pathFile .. '" -o "' .. fullPathNoExt .. '"'):add('"' .. fullPathNoExt .. '"'),
    })
  elseif dst == Keys.runFile then
    co.runner.run({
      name = 'Run "' .. nameNoExt .. '"',
      cmds = co.cmd.new():add('"' .. fullPathNoExt .. '"'),
    })
  end
end

return M
