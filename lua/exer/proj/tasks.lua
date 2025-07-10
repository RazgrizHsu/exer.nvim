local M = {}

local compiler = require('exer.proj.compiler')
local mods = require('exer.mods')

function M.findCompileFiles(entry, pattern)
  if not entry or not pattern then return entry or '' end

  local entryDir = vim.fn.fnamemodify(entry, ':h')
  local files = {}

  local globPattern = entryDir .. '/' .. pattern:gsub('%*', '*')
  local matches = vim.fn.glob(globPattern, false, true)

  for _, match in ipairs(matches) do
    table.insert(files, '"' .. match .. '"')
  end

  if #files == 0 then return '"' .. entry .. '"' end

  return table.concat(files, ' ')
end

function M.generateBuildTask(app, lang)
  local appType = app.type or compiler.inferType(app.entry)
  local co = require('exer.core')

  if appType == 'script' then return nil end

  -- 1. First check for custom build command
  if app.build_cmd then
    co.lg.debug(string.format('Using custom build command for app: %s', app.name), 'Tasks')
    return {
      name = string.format('[Build] %s', app.name),
      cmd = app.build_cmd,
    }
  end

  -- 2. Try to get compiler from project config
  local projCfg = require('exer.proj').load()
  local compilerCmd = nil

  if projCfg.compilers and projCfg.compilers[lang] and projCfg.compilers[lang][appType] then
    local profile = app.profile or 'default'
    compilerCmd = projCfg.compilers[lang][appType][profile]
    if compilerCmd then co.lg.debug(string.format('Using project compiler config for app: %s', app.name), 'Tasks') end
  end

  -- 3. Try to get compiler from language module
  if not compilerCmd then
    local langMod = mods.search('langs', lang)

    if langMod and langMod.getCompileCmd then
      compilerCmd = langMod.getCompileCmd(appType, app.profile or 'default')
      if compilerCmd then co.lg.debug(string.format('Using language module compiler for app: %s', app.name), 'Tasks') end
    end
  end

  -- 4. Fall back to legacy compiler system
  if not compilerCmd then
    local compilerFn = compiler.getCompiler(lang, appType)
    if not compilerFn then
      co.lg.debug(string.format('No compiler found for app: %s (lang: %s, type: %s)', app.name, lang or 'unknown', appType), 'Tasks')
      return nil
    end
    -- Continue with legacy compiler
    local files
    if app.files then
      if type(app.files) == 'string' then
        files = M.findCompileFiles(app.entry, app.files)
      elseif type(app.files) == 'table' then
        local filesList = {}
        for _, pattern in ipairs(app.files) do
          local foundFiles = M.findCompileFiles(app.entry, pattern)
          table.insert(filesList, foundFiles)
        end
        files = table.concat(filesList, ' ')
      end
    else
      local ext = app.entry:match('%.([^%.]+)$')
      if ext then
        files = M.findCompileFiles(app.entry, '*.' .. ext)
      else
        files = '"' .. app.entry .. '"'
      end
    end

    compilerCmd = compilerFn(files, app.output, app.build_args)
  else
    -- Using language module compiler - need to expand variables
    local expandVars = require('exer.proj.vars').expandVars

    -- Prepare files variable
    local files
    if app.files then
      if type(app.files) == 'string' then
        files = M.findCompileFiles(app.entry, app.files)
      elseif type(app.files) == 'table' then
        local filesList = {}
        for _, pattern in ipairs(app.files) do
          local foundFiles = M.findCompileFiles(app.entry, pattern)
          table.insert(filesList, foundFiles)
        end
        files = table.concat(filesList, ' ')
      end
    else
      local ext = app.entry:match('%.([^%.]+)$')
      if ext then
        files = M.findCompileFiles(app.entry, '*.' .. ext)
      else
        files = '"' .. app.entry .. '"'
      end
    end

    -- Expand variables in compiler command
    compilerCmd = compilerCmd:gsub('${files}', files)
    compilerCmd = compilerCmd:gsub('${output}', app.output)
    compilerCmd = compilerCmd:gsub('${args}', table.concat(app.build_args or {}, ' '))
    compilerCmd = expandVars(compilerCmd)
  end

  local outputDir = vim.fn.fnamemodify(app.output, ':h')
  local mkdirCmd = 'mkdir -p "' .. outputDir .. '"'

  local cleanCmd = 'rm -f "' .. app.output .. '"'

  return {
    name = string.format('[Build] %s', app.name),
    cmd = { mkdirCmd, cleanCmd, compilerCmd },
  }
end

function M.generateRunTask(app)
  local appType = app.type or compiler.inferType(app.entry)
  local lang = compiler.inferLang(app.entry)
  local co = require('exer.core')
  local cmd

  -- 1. First check for custom run command
  if app.run_cmd then
    co.lg.debug(string.format('Using custom run command for app: %s', app.name), 'Tasks')
    cmd = app.run_cmd
  else
    -- 2. Try to get run command from language module
    local langMod = mods.search('langs', lang)
    if langMod and langMod.getRunCmd then
      local runCmd = langMod.getRunCmd(appType, app.output)
      if runCmd then
        co.lg.debug(string.format('Using language module run command for app: %s', app.name), 'Tasks')
        -- Expand variables
        local expandVars = require('exer.proj.vars').expandVars
        runCmd = runCmd:gsub('${output}', app.output)
        runCmd = runCmd:gsub('${file}', app.entry)
        cmd = expandVars(runCmd)
      end
    end

    -- 3. Fall back to legacy run commands
    if not cmd then
      if appType == 'binary' then
        cmd = '"' .. app.output .. '"'
      elseif appType == 'class' then
        local className = vim.fn.fnamemodify(app.entry, ':t:r')
        cmd = string.format('java -cp "%s" %s', app.output, className)
      elseif appType == 'jar' then
        cmd = string.format('java -jar "%s"', app.output)
      elseif appType == 'script' then
        local ext = app.entry:match('(%.[^%.]+)$') or ''
        local interpreter = compiler.getInterpreter(ext) or 'bash'
        cmd = string.format('%s "%s"', interpreter, app.entry)
      end
    end
  end

  if cmd and app.run_args and #app.run_args > 0 then cmd = cmd .. ' ' .. table.concat(app.run_args, ' ') end

  return {
    name = string.format('[Run] %s', app.name),
    cmd = cmd,
  }
end

function M.generateBuildAndRunTask(app, lang)
  local buildTask = M.generateBuildTask(app, lang)
  local runTask = M.generateRunTask(app)

  if not buildTask then return runTask end

  local cmd = {}
  if type(buildTask.cmd) == 'table' then
    vim.list_extend(cmd, buildTask.cmd)
  else
    table.insert(cmd, buildTask.cmd)
  end

  if type(runTask.cmd) == 'table' then
    vim.list_extend(cmd, runTask.cmd)
  else
    table.insert(cmd, runTask.cmd)
  end

  return {
    name = string.format('[Build & Run] %s', app.name),
    cmd = cmd,
  }
end

function M.processApps(apps, _)
  if not apps or #apps == 0 then return {} end

  local acts = {}
  local co = require('exer.core')

  for _, app in ipairs(apps) do
    if not app or type(app) ~= 'table' then
      co.lg.debug('Skipping invalid app: not a table', 'Tasks')
      goto continue
    end

    if not app.name or not app.entry or not app.output then
      co.lg.debug(string.format('Skipping incomplete app: %s', app.name or 'unnamed'), 'Tasks')
      goto continue
    end

    local lang = compiler.inferLang(app.entry)
    if not lang then co.lg.debug(string.format('Cannot infer language for app: %s', app.name), 'Tasks') end

    local buildTask = M.generateBuildTask(app, lang)
    if buildTask and buildTask.cmd and buildTask.cmd ~= '' then
      table.insert(acts, {
        id = string.format('build: %s', app.name),
        name = buildTask.name,
        cmd = buildTask.cmd,
        type = 'app_build',
      })
    end

    local runTask = M.generateRunTask(app)
    if runTask and runTask.cmd and runTask.cmd ~= '' then table.insert(acts, {
      id = string.format('run: %s', app.name),
      name = runTask.name,
      cmd = runTask.cmd,
      type = 'app_run',
    }) end

    if buildTask and buildTask.cmd then
      local buildAndRunTask = M.generateBuildAndRunTask(app, lang)
      if buildAndRunTask and buildAndRunTask.cmd and buildAndRunTask.cmd ~= '' then
        table.insert(acts, {
          id = string.format('build & run: %s', app.name),
          name = buildAndRunTask.name,
          cmd = buildAndRunTask.cmd,
          type = 'app_build_run',
        })
      end
    end

    ::continue::
  end

  return acts
end

return M
