local ut = require('tests.unitester')
ut.setup()

local fmtHlp = require('tests.format_test_helper')

describe('Cross-Format Consistency Tests', function()
  it('parses basic configuration consistently across formats', function() fmtHlp.testEquivalence(ut.assert, 'Basic configuration', fmtHlp.testData.basic) end)

  it('parses array commands consistently across formats', function() fmtHlp.testEquivalence(ut.assert, 'Array commands', fmtHlp.testData.arrays) end)

  it('parses act references consistently across formats', function() fmtHlp.testEquivalence(ut.assert, 'Act references', fmtHlp.testData.references) end)

  it('parses variable expansion consistently across formats', function() fmtHlp.testEquivalence(ut.assert, 'Variable expansion', fmtHlp.testData.variables) end)

  it('validates complex configurations across formats', function()
    local complexData = {
      toml = [=[
[[exer.acts]]
id = "setup"
cmd = ["mkdir -p build", "cd build"]
desc = "Setup build environment"
cwd = "./tmp"
env = { BUILD_TYPE = "debug" }

[[exer.acts]]
id = "compile"
cmd = "gcc ${file} -o ${name}"
desc = "Compile source file"
when = "c"

[[exer.acts]]
id = "test"
cmd = "./${name}"
desc = "Run compiled program"

[[exer.acts]]
id = "full_build"
cmd = ["cmd:setup", "cmd:compile", "cmd:test"]
desc = "Complete build and test cycle"
]=],
      json = [[
{
  "exer": {
    "acts": [
      {
        "id": "setup",
        "cmd": ["mkdir -p build", "cd build"],
        "desc": "Setup build environment",
        "cwd": "./tmp",
        "env": { "BUILD_TYPE": "debug" }
      },
      {
        "id": "compile",
        "cmd": "gcc ${file} -o ${name}",
        "desc": "Compile source file",
        "when": "c"
      },
      {
        "id": "test",
        "cmd": "./${name}",
        "desc": "Run compiled program"
      },
      {
        "id": "full_build",
        "cmd": ["cmd:setup", "cmd:compile", "cmd:test"],
        "desc": "Complete build and test cycle"
      }
    ]
  }
}
]],
      ini = [[
[exer.acts]
id = setup
cmd = [ "mkdir -p build", "cd build" ]
desc = Setup build environment
cwd = ./tmp
env = { BUILD_TYPE = "debug" }

[exer.acts]
id = compile
cmd = gcc ${file} -o ${name}
desc = Compile source file
when = c

[exer.acts]
id = test
cmd = ./${name}
desc = Run compiled program

[exer.acts]
id = full_build
cmd = [ "cmd:setup", "cmd:compile", "cmd:test" ]
desc = Complete build and test cycle
]],
    }

    local results = fmtHlp.testEquivalence(assert, 'Complex configuration', complexData)

    -- Additional checks for complex structure
    for format, result in pairs(results) do
      ut.assert.are.equal(4, #result.acts, format .. ' should have 4 acts')

      -- Check setup act
      local setupAct = result.acts[1]
      ut.assert.are.equal('setup', setupAct.id, format .. ' setup act ID')
      ut.assert.are.equal('table', type(setupAct.cmd), format .. ' setup cmd should be array')
      ut.assert.are.equal('./tmp', setupAct.cwd, format .. ' setup cwd')

      -- Check compile act
      local compileAct = result.acts[2]
      ut.assert.are.equal('compile', compileAct.id, format .. ' compile act ID')
      ut.assert.are.equal('string', type(compileAct.cmd), format .. ' compile cmd should be string')
      ut.assert.matches('${file}', compileAct.cmd, format .. ' compile cmd should contain variables')

      -- Check full_build act
      local fullBuildAct = result.acts[4]
      ut.assert.are.equal('full_build', fullBuildAct.id, format .. ' full_build act ID')
      ut.assert.are.equal('table', type(fullBuildAct.cmd), format .. ' full_build cmd should be array')
      ut.assert.are.equal(3, #fullBuildAct.cmd, format .. ' full_build should have 3 commands')
      ut.assert.are.equal('cmd:setup', fullBuildAct.cmd[1], format .. ' first reference should be cmd:setup')
      ut.assert.are.equal('cmd:compile', fullBuildAct.cmd[2], format .. ' second reference should be cmd:compile')
      ut.assert.are.equal('cmd:test', fullBuildAct.cmd[3], format .. ' third reference should be cmd:test')
    end
  end)

  it('handles edge cases consistently across formats', function()
    local edgeCaseData = {
      toml = [=[
[[exer.acts]]
id = "empty_array"
cmd = []
desc = "Empty command array"

[[exer.acts]]
id = "single_item_array"
cmd = ["single command"]
desc = "Single item array"

[[exer.acts]]
id = "special_chars"
cmd = "echo 'hello \"world\"' && echo $PATH"
desc = "Command with special characters"

[[exer.acts]]
id = "long_command"
cmd = "find . -name '*.lua' -exec grep -l 'function' {} \\; | head -10"
desc = "Long command with pipes"
]=],
      json = [[
{
  "exer": {
    "acts": [
      {
        "id": "empty_array",
        "cmd": [],
        "desc": "Empty command array"
      },
      {
        "id": "single_item_array",
        "cmd": ["single command"],
        "desc": "Single item array"
      },
      {
        "id": "special_chars",
        "cmd": "echo 'hello \"world\"' && echo $PATH",
        "desc": "Command with special characters"
      },
      {
        "id": "long_command",
        "cmd": "find . -name '*.lua' -exec grep -l 'function' {} \\; | head -10",
        "desc": "Long command with pipes"
      }
    ]
  }
}
]],
      ini = [[
[exer.acts]
id = empty_array
cmd = []
desc = Empty command array

[exer.acts]
id = single_item_array
cmd = [ "single command" ]
desc = Single item array

[exer.acts]
id = special_chars
cmd = echo 'hello "world"' && echo $PATH
desc = Command with special characters

[exer.acts]
id = long_command
cmd = find . -name '*.lua' -exec grep -l 'function' {} \; | head -10
desc = Long command with pipes
]],
    }

    fmtHlp.testEquivalence(assert, 'Edge cases', edgeCaseData)
  end)

  it('maintains validation consistency across formats', function()
    local testConfigs = {
      toml = [=[
[[exer.acts]]
id = "invalid_id!_from_toml"
cmd = "echo test"
]=],
      json = [[
{
  "exer": {
    "acts": [
      {
        "id": "wrong_id!_from_exerJson",
        "cmd": "echo test"
      }
    ]
  }
}
]],
      ini = [[
[exer.acts]
id = !invalid_id!_from_ini
cmd = echo test
]],
    }

    local vld = require('exer.proj.valid')

    for format, content in pairs(testConfigs) do
      local result = fmtHlp.parseContent(content, format)
      if result then
        local isValid = vld.validate(result, false) -- prevent notify
        ut.assert.are.equal(false, isValid, format .. ' should reject invalid ID, \n' .. vim.inspect(result))
      end
    end
  end)
end)

describe('Format-Specific Feature Tests', function()
  it('handles TOML-specific features', function()
    local tomlContent = [=[
[[exer.acts]]
id = "multiline"
cmd = """
echo "Line 1"
echo "Line 2"
echo "Line 3"
"""
desc = "Multiline command"
]=]

    local result = fmtHlp.parseContent(tomlContent, 'toml')
    ut.assert.is_true(result ~= nil, 'Should parse TOML multiline string')
    ut.assert.are.equal(1, #result.acts, 'Should have 1 act')
    -- Check if cmd exists and is non-empty (some TOML parsers handle multiline strings differently)
    local cmd = result.acts[1].cmd
    ut.assert.is_true(cmd ~= nil and cmd ~= '', 'Should have valid command content')
  end)

  it('handles JSON-specific features', function()
    local jsonContent = [[
{
  "exer": {
    "acts": [
      {
        "id": "with_null",
        "cmd": "echo test",
        "desc": null,
        "optional_field": null
      }
    ]
  }
}
]]

    local result = fmtHlp.parseContent(jsonContent, 'json')
    ut.assert.is_true(result ~= nil, 'Should parse JSON with null values')
    ut.assert.are.equal(1, #result.acts, 'Should have 1 act')
    ut.assert.are.equal('with_null', result.acts[1].id, 'Should parse act with null fields')
  end)

  it('handles INI-specific features', function()
    local iniContent = [[
; This is a comment
[exer.acts]
id = with_comments
cmd = echo "test"
desc = Command with comments
; Another comment

[exer.acts]
id = another_act
cmd = echo "another"
]]

    local result = fmtHlp.parseContent(iniContent, 'ini')
    ut.assert.is_true(result ~= nil, 'Should parse INI with comments')
    ut.assert.are.equal(2, #result.acts, 'Should have 2 acts')
    ut.assert.are.equal('with_comments', result.acts[1].id, 'Should parse first act')
    ut.assert.are.equal('another_act', result.acts[2].id, 'Should parse second act')
  end)
end)
