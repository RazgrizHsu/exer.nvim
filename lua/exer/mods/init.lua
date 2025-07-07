local M = {}
local co = require('exer.core')

local excludeDirs = { 'node_modules', '.git', 'tmp', '.vscode', 'dist' }

function M.scanMods()
  local pathL = debug.getinfo(1, 'S').source:sub(2)
  local pathLDir = pathL:match('(.*[/\\\\])')
  local modules = {}

  co.log.debug('Scanning mods directory: ' .. pathLDir, 'ModsScan')

  local function shouldExclude(dirName)
    for _, exclude in ipairs(excludeDirs) do
      if dirName == exclude then return true end
    end
    return false
  end

  local function scanDir(dir, category)
    co.log.debug('Scanning category directory: ' .. dir .. ' (category: ' .. category .. ')', 'ModsScan')
    local handle = vim.loop.fs_scandir(dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end

        if type == 'file' and name:match('%.lua$') then
          local modName = name:match('(.+)%.lua$')
          co.log.debug('Found module: ' .. category .. '/' .. modName, 'ModsScan')
          table.insert(modules, {
            name = modName,
            category = category,
            path = category .. '/' .. name,
          })
        end
      end
    else
      co.log.debug('Failed to open directory: ' .. dir, 'ModsScan')
    end
  end

  local handle = vim.loop.fs_scandir(pathLDir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end

      co.log.debug('Found item: ' .. name .. ' (type: ' .. type .. ')', 'ModsScan')

      if type == 'directory' and not shouldExclude(name) then
        local dirPath = pathLDir .. name
        co.log.debug('Scanning subdirectory: ' .. dirPath, 'ModsScan')
        scanDir(dirPath, name)
      elseif type == 'directory' then
        co.log.debug('Excluding directory: ' .. name, 'ModsScan')
      end
    end
  else
    co.log.debug('Failed to open mods directory: ' .. pathLDir, 'ModsScan')
  end

  return modules
end

function M.search(category, modName)
  local pathL = debug.getinfo(1, 'S').source:sub(2)
  local pathLDir = pathL:match('(.*[/\\\\])')
  local pathModFile = co.utils.osPath(pathLDir .. category .. '/' .. modName .. '.lua')
  local ok, mod = pcall(dofile, pathModFile)

  if ok then
    return mod
  else
    return nil
  end
end

function M.getOpts(ft)
  local pathWorkDir = vim.fn.getcwd()
  local pathFile = vim.fn.expand('%:p')
  local opts = {}
  local modules = M.scanMods()

  co.log.debug('=== MODS SCANNING STARTED ===', 'Mods')
  co.log.debug('Working directory: ' .. pathWorkDir, 'Mods')
  co.log.debug('Filetype: ' .. (ft or 'nil'), 'Mods')
  co.log.debug('Found ' .. #modules .. ' modules: ' .. vim.inspect(modules), 'Mods')

  for _, modInfo in ipairs(modules) do
    local mod = M.search(modInfo.category, modInfo.name)
    if mod then
      local shouldInclude = false

      -- Language modules (langs category) use fileTypes for matching
      if modInfo.category == 'langs' then
        if mod.fileTypes and ft then
          for _, supportedFt in ipairs(mod.fileTypes) do
            if supportedFt == ft then
              shouldInclude = true
              co.log.debug(string.format('Language module %s/%s matches filetype: %s', modInfo.category, modInfo.name, ft), 'Mods')
              break
            end
          end
        end
      else
        -- Non-language modules (build, test, etc) use detect() method
        if mod.detect then
          shouldInclude = mod.detect(pathWorkDir)
          co.log.debug(string.format('Module %s/%s detect result: %s', modInfo.category, modInfo.name, tostring(shouldInclude)), 'Mods')
        else
          co.log.debug(string.format('Module %s/%s missing detect function', modInfo.category, modInfo.name), 'Mods')
        end
      end

      if shouldInclude and mod.getOpts then
        local modOpts = mod.getOpts(pathWorkDir, pathFile, ft)

        -- Add module info to each option for identification
        for _, opt in ipairs(modOpts) do
          opt._modInfo = modInfo
        end

        co.log.debug(string.format('Module %s/%s returned %d options', modInfo.category, modInfo.name, #modOpts), 'Mods')

        vim.list_extend(opts, modOpts)
      end
    else
      co.log.debug(string.format('Module %s/%s failed to load', modInfo.category, modInfo.name), 'Mods')
    end
  end

  co.log.debug('Total mods options: ' .. #opts, 'Mods')

  return opts
end

function M.runAct(option)
  local pathWorkDir = vim.fn.getcwd()
  local pathFile = vim.fn.expand('%:p')
  local ft = vim.bo.filetype
  local modules = M.scanMods()

  for _, modInfo in ipairs(modules) do
    local mod = M.search(modInfo.category, modInfo.name)
    if mod and mod.runAct then
      local shouldCheck = false

      -- Language modules (langs category) don't need detect() - they're always available
      if modInfo.category == 'langs' then
        shouldCheck = true
      else
        -- Non-language modules use detect() method
        shouldCheck = mod.detect and mod.detect(pathWorkDir)
      end

      if shouldCheck then
        local opts = mod.getOpts and mod.getOpts(pathWorkDir, pathFile, ft) or {}

        for _, opt in ipairs(opts) do
          if opt.value == option then
            local success, err = pcall(mod.runAct, option, pathWorkDir, pathFile)
            if success then
              return
            else
              co.utils.msg('Error executing module action: ' .. tostring(err), vim.log.levels.ERROR)
              return
            end
          end
        end
      end
    end
  end

  co.utils.msg('No module found to handle option: ' .. tostring(option), vim.log.levels.WARN)
end

return M
