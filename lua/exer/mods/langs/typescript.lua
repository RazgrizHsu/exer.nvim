local M = {}

local Keys = {
  checkFile = 'ts:checkFile',
  compileFile = 'ts:compileFile',
  runTsNode = 'ts:runTsNode',
  checkProj = 'ts:checkProj',
  buildProj = 'ts:buildProj',
}

--========================================================================
-- public define
--========================================================================
-- Language modules use fileTypes instead of detect() for matching
M.fileTypes = { 'typescript', 'typescriptreact' }

-- Compiler configurations for different app types and profiles
M.compiler = {
  binary = {
    default = 'npx tsc ${files} --outDir "${output}"',
    debug = 'npx tsc ${files} --outDir "${output}" --sourceMap --inlineSourceMap',
    release = 'npx tsc ${files} --outDir "${output}" --removeComments --declaration false',
  },
  module = {
    default = 'npx tsc ${files} --module commonjs --outDir "${output}"',
    debug = 'npx tsc ${files} --module commonjs --outDir "${output}" --sourceMap',
    release = 'npx tsc ${files} --module commonjs --outDir "${output}" --removeComments',
  },
  script = {
    default = nil, -- Scripts don't need compilation
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

  if pathFile and pathFile:match('%.tsx?$') then
    opts:addLang('Check file syntax', Keys.checkFile, 'typescript', 'TS')
    opts:addLang('Compile file', Keys.compileFile, 'typescript', 'TS')
    opts:addLang('Run with ts-node', Keys.runTsNode, 'typescript', 'TS')
  end

  if co.io.fileExists(pathWorkDir .. '/tsconfig.json') then
    opts:addLang('Check project', Keys.checkProj, 'typescript', 'TS')
    opts:addLang('Build project', Keys.buildProj, 'typescript', 'TS')
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
  if appType == 'binary' or appType == 'module' then
    return 'node "${output}/index.js"'
  elseif appType == 'script' then
    return 'ts-node "${file}"'
  end
  return nil
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(dst, pathWorkDir, pathFile)
  local filename = vim.fn.fnamemodify(pathFile, ':t')

  if dst == Keys.checkFile then
    co.runner.run({
      name = 'Check "' .. filename .. '"',
      cmds = co.cmd.new():add('npx tsc "' .. pathFile .. '" --noEmit'),
    })
  elseif dst == Keys.compileFile then
    co.runner.run({
      name = 'Compile "' .. filename .. '"',
      cmds = co.cmd.new():add('npx tsc "' .. pathFile .. '"'),
    })
  elseif dst == Keys.runTsNode then
    co.runner.run({
      name = 'Run "' .. filename .. '" with ts-node',
      cmds = co.cmd.new():add('ts-node "' .. pathFile .. '"'),
    })
  elseif dst == Keys.checkProj then
    co.runner.run({
      name = 'Check project',
      cmds = co.cmd.new():cd(pathWorkDir):add('npx tsc --noEmit'),
    })
  elseif dst == Keys.buildProj then
    co.runner.run({
      name = 'Build project',
      cmds = co.cmd.new():cd(pathWorkDir):add('npx tsc'),
    })
  end
end

return M
