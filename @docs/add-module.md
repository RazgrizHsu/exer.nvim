# Module Development Guide

## Creating Custom Modules

Exer.nvim supports custom modules for languages, build tools, test frameworks, and utilities. Follow these guidelines to create your own modules:

### Module Structure

All modules must follow this standardized structure:

```lua
local M = {}

-- Define unique keys for your module's actions
local Keys = {
  action1 = 'module_name:action1',
  action2 = 'module_name:action2',
}

--========================================================================
-- private
--========================================================================
local co = require('exer.core')

--========================================================================
-- Detect
--========================================================================
function M.detect(workDir)
  -- Return true if this module should be available in the current project
  -- Example: Check for config files, package managers, etc.
  return co.io.findFile(workDir, {'package.json', 'pom.xml'}) ~= nil
end

--========================================================================
-- Opts
--========================================================================
function M.getOpts(workDir, pathFile, ft)
  if not M.detect(workDir) then return {} end
  
  local opts = require('exer.picker.opts').new()
  
  -- Add options based on module type:
  -- Language modules: opts:addLang(text, value, name, type)
  -- Build modules: opts:addBu(text, value, name, type)
  -- Test modules: opts:addTf(text, value, name, type)
  -- Utility modules: opts:addUtil(text, value, name, type)
  opts:addUtil('format code', Keys.action1, 'module_name')
  
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

  if option == Keys.action1 then
    name = 'Module: Action Description'
    cmd = 'your-command-here'
  else
    co.utils.msg('Unknown module option: ' .. option, vim.log.levels.ERROR)
    return
  end

  co.runner.run({
    name = name,
    cmds = co.cmd.new():cd(workDir):add(cmd),
  })
end

return M
```

### Module Categories

**Language Modules** (`mods/langs/`)
- Use `fileTypes` array instead of `detect()` function
- Add `fileTypes = {'python', 'py'}` to support specific file types
- Use `opts:addLang()` for options

**Build Tool Modules** (`mods/build/`)
- Implement `detect()` to check for build files (Makefile, CMakeLists.txt, etc.)
- Use `opts:addBu()` for build options
- Focus on compilation and project building tasks

**Test Framework Modules** (`mods/test/`)
- Implement `detect()` to identify test frameworks
- Use `opts:addTf()` for test options
- Support running individual tests and test suites

**Utility Modules** (`mods/utils/`)
- Implement `detect()` for tool availability
- Use `opts:addUtil()` for utility options
- Provide development tools like formatters, linters, etc.

### Best Practices

1. **Error Handling**: Always validate inputs and provide meaningful error messages
2. **Naming**: Use descriptive action keys with module prefix (e.g., `python:run`, `jest:test`)
3. **Detection**: Make `detect()` efficient and accurate
4. **Commands**: Use absolute paths and proper escaping for file paths
5. **Documentation**: Comment complex logic and provide clear option descriptions

### File Location

Place your module in the appropriate category directory:
- `lua/exer/mods/langs/your_language.lua`
- `lua/exer/mods/build/your_build_tool.lua`
- `lua/exer/mods/test/your_test_framework.lua`
- `lua/exer/mods/utils/your_utility.lua`

The module system will automatically discover and load your modules.

