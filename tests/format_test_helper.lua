local ut = require('tests.unitester')
local M = {}

-- Test data structure for consistent testing across formats
M.testData = {
  basic = {
    toml = [[
\[\[exer.acts\]\]
id = "run"
cmd = "python main.py"
desc = "Run the application"
]],
    json = [[
{
  "exer": {
    "acts": [
      {
        "id": "run",
        "cmd": "python main.py",
        "desc": "Run the application"
      }
    ]
  }
}
]],
    ini = [[
[exer.acts]
id = run
cmd = python main.py
desc = Run the application
]],
  },

  arrays = {
    toml = [[
\[\[exer.acts\]\]
id = "sequential"
cmd = ["build", "test"]
desc = "Sequential execution"

\[\[exer.acts\]\]
id = "parallel"
cmds = ["lint", "format"]
desc = "Parallel execution"
]],
    json = [[
{
  "exer": {
    "acts": [
      {
        "id": "sequential",
        "cmd": ["build", "test"],
        "desc": "Sequential execution"
      },
      {
        "id": "parallel",
        "cmds": ["lint", "format"],
        "desc": "Parallel execution"
      }
    ]
  }
}
]],
    ini = [[
[exer.acts]
id = sequential
cmd = [ "build", "test" ]
desc = Sequential execution

[exer.acts]
id = parallel
cmds = [ "lint", "format" ]
desc = Parallel execution
]],
  },

  references = {
    toml = [[
\[\[exer.acts\]\]
id = "build"
cmd = "gcc main.c -o main"

[[exer.acts\]\]
id = "test"
cmd = "npm test"

[[exer.acts\]\]
id = "ci"
cmd = ["cmd:build", "cmd:test"]
desc = "CI pipeline"
]],
    json = [[
{
  "exer": {
    "acts": [
      {
        "id": "build",
        "cmd": "gcc main.c -o main"
      },
      {
        "id": "test",
        "cmd": "npm test"
      },
      {
        "id": "ci",
        "cmd": ["cmd:build", "cmd:test"],
        "desc": "CI pipeline"
      }
    ]
  }
}
]],
    ini = [[
[exer.acts]
id = build
cmd = gcc main.c -o main

[exer.acts]
id = test
cmd = npm test

[exer.acts]
id = ci
cmd = [ "cmd:build", "cmd:test" ]
desc = CI pipeline
]],
  },

  variables = {
    toml = [[
[[exer.acts\]\]
id = "compile"
cmd = "gcc ${file} -o ${name}"
desc = "Compile current file"
]],
    json = [[
{
  "exer": {
    "acts": [
      {
        "id": "compile",
        "cmd": "gcc ${file} -o ${name}",
        "desc": "Compile current file"
      }
    ]
  }
}
]],
    ini = [[
[exer.acts]
id = compile
cmd = gcc ${file} -o ${name}
desc = Compile current file
]],
  },
}

-- Parse content using appropriate parser
function M.parseContent(content, format)
  if format == 'toml' then
    local proj = require('exer.proj')
    return proj.parse(content, 'toml')
  elseif format == 'json' then
    local proj = require('exer.proj')
    return proj.parse(content, 'json')
  elseif format == 'ini' then
    local editorconfig = require('exer.core.psr.editorconfig')
    local exerContent = editorconfig.extractExerSection(content)
    if exerContent then
      local convertedToml = editorconfig.convertIniToToml(exerContent)
      if convertedToml then
        local proj = require('exer.proj')
        return proj.parse(convertedToml, 'toml')
      end
    end
    return nil
  else
    error('Unsupported format: ' .. format)
  end
end

-- Test that all formats produce equivalent results
function M.testEquivalence(assert, testName, testData)
  local results = {}

  for format, content in pairs(testData) do
    local result = M.parseContent(content, format)
    results[format] = result
    assert.is_true(result ~= nil, string.format('%s: %s format should parse successfully', testName, format))
  end

  -- Compare acts arrays
  local tomlActs = results.toml.acts or {}
  local jsonActs = results.json.acts or {}
  local iniActs = results.ini and results.ini.acts or {}

  assert.are.equal(#tomlActs, #jsonActs, string.format('%s: TOML and JSON should have same number of acts', testName))
  assert.are.equal(#tomlActs, #iniActs, string.format('%s: TOML and INI should have same number of acts', testName))

  -- Compare act content
  for i, tomlAct in ipairs(tomlActs) do
    local jsonAct = jsonActs[i]
    local iniAct = iniActs[i]

    assert.are.equal(tomlAct.id, jsonAct.id, string.format('%s: Act %d ID should match between TOML and JSON', testName, i))
    assert.are.equal(tomlAct.id, iniAct.id, string.format('%s: Act %d ID should match between TOML and INI', testName, i))

    -- Compare commands (handle both string and array)
    M.compareCommands(assert, tomlAct.cmd or tomlAct.cmds, jsonAct.cmd or jsonAct.cmds, string.format('%s: Act %d cmd (TOML vs JSON)', testName, i))
    M.compareCommands(assert, tomlAct.cmd or tomlAct.cmds, iniAct.cmd or iniAct.cmds, string.format('%s: Act %d cmd (TOML vs INI)', testName, i))
  end

  return results
end

-- Helper to compare commands (string or array)
function M.compareCommands(assert, cmd1, cmd2, message)
  if type(cmd1) ~= type(cmd2) then assert.fail(message .. ' - type mismatch: ' .. type(cmd1) .. ' vs ' .. type(cmd2)) end

  if type(cmd1) == 'string' then
    assert.are.equal(cmd1, cmd2, message)
  elseif type(cmd1) == 'table' then
    assert.are.equal(#cmd1, #cmd2, message .. ' - array length mismatch')
    for i, v in ipairs(cmd1) do
      assert.are.equal(v, cmd2[i], message .. ' - array element ' .. i .. ' mismatch')
    end
  end
end

-- Test executor behavior with different formats
function M.testExecutorBehavior(assert, testName, testData)
  -- Setup mock environment
  local mockTasks = {}
  local function mockRun(config) table.insert(mockTasks, config) end

  -- Override the runner module
  package.loaded['exer.core.runner'] = {
    run = mockRun,
  }

  local executor = require('exer.proj.executor')

  for format, content in pairs(testData) do
    local result = M.parseContent(content, format)
    if result and result.acts then
      mockTasks = {}

      for _, act in ipairs(result.acts) do
        executor.executeAct(act, result.acts)
      end

      -- Verify execution results
      assert.is_true(#mockTasks > 0, string.format('%s: %s format should create tasks', testName, format))

      -- Store results for comparison
      result.executionTasks = mockTasks
    end
  end

  return results
end

return M
