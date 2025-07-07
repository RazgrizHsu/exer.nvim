local M = {}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')


--========================================================================
-- Detect
--========================================================================
function M.detect(pathWorkDir)
  return co.io.fileExists(pathWorkDir .. '/Cargo.toml')
end

--========================================================================
-- Opts
--========================================================================
function M.getOpts(pathWorkDir, pathFile, fileType)
  if not M.detect(pathWorkDir) then return {} end

  local opts = require('exer.picker.opts').new()

  opts:addBu('Build project', 'cargo:build', 'cargo', 'Cargo')
  opts:addBu('Build release', 'cargo:build_release', 'cargo', 'Cargo')
  opts:addBu('Run project', 'cargo:run', 'cargo', 'Cargo')
  opts:addBu('Run release', 'cargo:run_release', 'cargo', 'Cargo')
  opts:addBu('Test project', 'cargo:test', 'cargo', 'Cargo')
  opts:addBu('Check project', 'cargo:check', 'cargo', 'Cargo')
  opts:addBu('Clean project', 'cargo:clean', 'cargo', 'Cargo')
  opts:addBu('Update dependencies', 'cargo:update', 'cargo', 'Cargo')
  opts:addBu('Format code', 'cargo:fmt', 'cargo', 'Cargo')
  opts:addBu('Lint code', 'cargo:clippy', 'cargo', 'Cargo')

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

  if option == 'cargo:build' then
    name = 'Cargo: Build'
    cmd = 'cargo build'
  elseif option == 'cargo:build_release' then
    name = 'Cargo: Build (Release)'
    cmd = 'cargo build --release'
  elseif option == 'cargo:run' then
    name = 'Cargo: Run'
    cmd = 'cargo run'
  elseif option == 'cargo:run_release' then
    name = 'Cargo: Run (Release)'
    cmd = 'cargo run --release'
  elseif option == 'cargo:test' then
    name = 'Cargo: Test'
    cmd = 'cargo test'
  elseif option == 'cargo:check' then
    name = 'Cargo: Check'
    cmd = 'cargo check'
  elseif option == 'cargo:clean' then
    name = 'Cargo: Clean'
    cmd = 'cargo clean'
  elseif option == 'cargo:update' then
    name = 'Cargo: Update'
    cmd = 'cargo update'
  elseif option == 'cargo:fmt' then
    name = 'Cargo: Format'
    cmd = 'cargo fmt'
  elseif option == 'cargo:clippy' then
    name = 'Cargo: Clippy'
    cmd = 'cargo clippy'
  else
    co.utils.msg('Unknown Cargo option: ' .. option, vim.log.levels.ERROR)
    return
  end

  co.runner.run({
    name = name,
    cmds = co.cmd.new():cd(pathWorkDir):add(cmd),
  })
end

--========================================================================
return M
