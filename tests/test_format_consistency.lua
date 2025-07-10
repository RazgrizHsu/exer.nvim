local ut = require('tests.unitester')
ut.setup()

local formatHelper = require('tests.format_test_helper')

describe('Cross-Format Consistency Tests', function()
  it('parses basic configuration consistently across formats', function() formatHelper.testEquivalence(assert, 'Basic configuration', formatHelper.testData.basic) end)

  it('parses array commands consistently across formats', function() formatHelper.testEquivalence(assert, 'Array commands', formatHelper.testData.arrays) end)

  it('parses act references consistently across formats', function() formatHelper.testEquivalence(assert, 'Act references', formatHelper.testData.references) end)

  it('parses variable expansion consistently across formats', function() formatHelper.testEquivalence(assert, 'Variable expansion', formatHelper.testData.variables) end)

  it('validates complex configurations across formats', function()
    local complexData = {
      toml = [[
[[exer.acts\]\]
id = "setup"
cmd = ["mkdir -p build", "cd build"]
desc = "Setup build environment"
cwd = "./tmp"
env = { BUILD_TYPE = "debug" }

[[exer.acts\]\]
id = "compile"
cmd = "gcc ${file} -o ${name}"
desc = "Compile source file"
when = "c"

[[exer.acts\]\]
id = "test"
cmd = "./${name}"
desc = "Run compiled program"

[[exer.acts\]\]
id = "full_build"
cmd = ["cmd:setup", "cmd:compile", "cmd:test"]
desc = "Complete build and test cycle"
]],
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

    local results = formatHelper.testEquivalence(assert, 'Complex configuration', complexData)

    -- Additional checks for complex structure
    for format, result in pairs(results) do
      assert.are.equal(4, #result.acts, format .. ' should have 4 acts')

      -- Check setup act
      local setupAct = result.acts[1]
      assert.are.equal('setup', setupAct.id, format .. ' setup act ID')
      assert.are.equal('table', type(setupAct.cmd), format .. ' setup cmd should be array')
      assert.are.equal('/tmp', setupAct.cwd, format .. ' setup cwd')

      -- Check compile act
      local compileAct = result.acts[2]
      assert.are.equal('compile', compileAct.id, format .. ' compile act ID')
      assert.are.equal('string', type(compileAct.cmd), format .. ' compile cmd should be string')
      assert.matches('${file}', compileAct.cmd, format .. ' compile cmd should contain variables')

      -- Check full_build act
      local fullBuildAct = result.acts[4]
      assert.are.equal('full_build', fullBuildAct.id, format .. ' full_build act ID')
      assert.are.equal('table', type(fullBuildAct.cmd), format .. ' full_build cmd should be array')
      assert.are.equal(3, #fullBuildAct.cmd, format .. ' full_build should have 3 commands')
      assert.are.equal('cmd:setup', fullBuildAct.cmd[1], format .. ' first reference should be cmd:setup')
      assert.are.equal('cmd:compile', fullBuildAct.cmd[2], format .. ' second reference should be cmd:compile')
      assert.are.equal('cmd:test', fullBuildAct.cmd[3], format .. ' third reference should be cmd:test')
    end
  end)

  it('handles edge cases consistently across formats', function()
    local edgeCaseData = {
      toml = [[
[[exer.acts\]\]
id = "empty_array"
cmd = []
desc = "Empty command array"

[[exer.acts\]\]
id = "single_item_array"
cmd = ["single command"]
desc = "Single item array"

[[exer.acts\]\]
id = "special_chars"
cmd = "echo 'hello \"world\"' && echo $PATH"
desc = "Command with special characters"

[[exer.acts\]\]
id = "long_command"
cmd = "find . -name '*.lua' -exec grep -l 'function' {} \\; | head -10"
desc = "Long command with pipes"
]],
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

    formatHelper.testEquivalence(assert, 'Edge cases', edgeCaseData)
  end)

  it('maintains validation consistency across formats', function()
    local testConfigs = {
      toml = [[
[[exer.acts\]\]
id = "invalid_id!"
cmd = "echo test"
]],
      json = [[
{
  "exer": {
    "acts": [
      {
        "id": "invalid_id!",
        "cmd": "echo test"
      }
    ]
  }
}
]],
      ini = [[
[exer.acts]
id = invalid_id!
cmd = echo test
]],
    }

    local validator = require('exer.proj.valid')

    for format, content in pairs(testConfigs) do
      local result = formatHelper.parseContent(content, format)
      if result then
        local isValid = validator.validate(result)
        assert.are.equal(false, isValid, format .. ' should reject invalid ID')
      end
    end
  end)
end)

describe('Format-Specific Feature Tests', function()
  ---@diagnostic disable-next-line: lowercase-global
  vim = ut.setup()

  it('handles TOML-specific features', function()
    local tomlContent = [[
[[exer.acts\]\]
id = "multiline"
cmd = """
echo "Line 1"
echo "Line 2"
echo "Line 3"
"""
desc = "Multiline command"
]]

    local result = formatHelper.parseContent(tomlContent, 'toml')
    assert.is_true(result ~= nil, 'Should parse TOML multiline string')
    assert.are.equal(1, #result.acts, 'Should have 1 act')
    assert.matches('Line 1', result.acts[1].cmd, 'Should preserve multiline content')
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

    local result = formatHelper.parseContent(jsonContent, 'json')
    assert.is_true(result ~= nil, 'Should parse JSON with null values')
    assert.are.equal(1, #result.acts, 'Should have 1 act')
    assert.are.equal('with_null', result.acts[1].id, 'Should parse act with null fields')
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

    local result = formatHelper.parseContent(iniContent, 'ini')
    assert.is_true(result ~= nil, 'Should parse INI with comments')
    assert.are.equal(2, #result.acts, 'Should have 2 acts')
    assert.are.equal('with_comments', result.acts[1].id, 'Should parse first act')
    assert.are.equal('another_act', result.acts[2].id, 'Should parse second act')
  end)
end)
