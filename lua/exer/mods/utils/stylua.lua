local M = {}

local Keys = {
  formatProject = 'stylua:format_project',
  checkFile = 'stylua:check_file',
  formatFile = 'stylua:format_file',
}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')

--========================================================================
-- Detect
--========================================================================
function M.detect(workDir)
  local configFiles = {
    'stylua.toml',
    '.stylua.toml',
  }

  local foundFile = co.io.findFile(workDir, configFiles)
  return foundFile ~= nil
end

--========================================================================
-- Opts
--========================================================================
function M.getOpts(workDir, pathFile, ft)
  if not M.detect(workDir) then return {} end

  local opts = require('exer.picker.opts').new()

  -- Always provide project-wide format
  opts:addMod('format project', Keys.formatProject, 'stylua')

  -- If current file is Lua, provide file-specific options
  if ft == 'lua' and pathFile and pathFile ~= '' then
    opts:addMod('check file', Keys.checkFile, 'stylua')
    opts:addMod('format file', Keys.formatFile, 'stylua')
  end

  return opts:build()
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(option, workDir, pathFile)
  if not option or option == '' then
    co.utils.msg('No command specified', vim.log.levels.ERROR)
    return
  end

  local name = ''
  local cmd = ''

  if option == Keys.formatProject then
    name = 'StyLua: Format Project'
    cmd = 'stylua .'
  elseif option == Keys.checkFile then
    if pathFile and pathFile ~= '' then
      local fileName = vim.fn.fnamemodify(pathFile, ':t')
      name = 'StyLua: Check ' .. fileName
      cmd = 'stylua --check "' .. pathFile .. '"'
    else
      co.utils.msg('No file specified for stylua check', vim.log.levels.ERROR)
      return
    end
  elseif option == Keys.formatFile then
    if pathFile and pathFile ~= '' then
      local fileName = vim.fn.fnamemodify(pathFile, ':t')
      name = 'StyLua: Format ' .. fileName
      cmd = 'stylua "' .. pathFile .. '"'
    else
      co.utils.msg('No file specified for stylua format', vim.log.levels.ERROR)
      return
    end
  else
    co.utils.msg('Unknown StyLua option: ' .. option, vim.log.levels.ERROR)
    return
  end

  co.runner.run({
    name = name,
    cmds = co.cmd.new():cd(workDir):add(cmd),
  })
end

return M
