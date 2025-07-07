local M = {}

local Keys = {
  install = 'node:install',
}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')

--========================================================================
-- Detect
--========================================================================
function M.detect(pathWorkDir)
  local packageJson = pathWorkDir .. co.utils.osPath('/package.json')

  co.log.debug('NodeJS detect called with pathWorkDir: ' .. pathWorkDir, 'NodeJS')
  co.log.debug('NodeJS detect checking: ' .. packageJson, 'NodeJS')

  if not co.io.fileExists(packageJson) then
    co.log.debug('package.json not found at: ' .. packageJson, 'NodeJS')
    return false
  end

  local hasRequiredFields = co.io.fileContains(packageJson, { '"name"', '"scripts"', '"version"' })

  co.log.debug('package.json found, has required fields: ' .. tostring(hasRequiredFields), 'NodeJS')

  return hasRequiredFields
end

--========================================================================
-- Opts
--========================================================================
function M.getOpts(pathWorkDir, pathFile, fileType)
  local pathPkg = pathWorkDir .. co.utils.osPath('/package.json')
  local jsonPkg = co.io.readJson(pathPkg)

  local opts = require('exer.picker.opts').new()

  if jsonPkg then
    local scripts = jsonPkg.scripts

    if scripts then
      opts:addBu('npm install', Keys.install, 'nodejs', 'Node')

      for script, _ in pairs(scripts) do
        local key = 'node:script:' .. script
        opts:addBu('npm run ' .. script, key, 'nodejs', 'Node')
      end
    end
  end

  return opts:build()
end

--========================================================================
-- Acts
--========================================================================
function M.runAct(option, pathWorkDir, pathFile)
  if not option or option == '' then
    co.utils.msg('No command specified', vim.log.levels.ERROR)
    return
  end

  local name = ''
  local cmd = ''

  if option == Keys.install then
    name = 'NodeJS: Install Dependencies'
    cmd = 'npm install'
  elseif option:match('^node:script:(.+)$') then
    local script = option:match('^node:script:(.+)$')
    name = 'NodeJS: Run ' .. script
    cmd = 'npm run ' .. script
  else
    co.utils.msg('Unknown NodeJS option: ' .. option, vim.log.levels.ERROR)
    return
  end

  co.runner.run({
    name = name,
    cmds = co.cmd.new():cd(pathWorkDir):add(cmd),
  })
end

return M
