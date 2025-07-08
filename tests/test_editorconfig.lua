package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

local helper = require('tests.helper')
local describe = helper.describe
local it = helper.it
local assert = helper.assert

describe('EditorConfig Parser', function()
  local editorconfig = require('exer.core.psr.editorconfig')

  it('should extract exer section from .editorconfig', function()
    local content = [[
root = true

[*]
indent_style = space
indent_size = 2

[exer]
acts = [
  { id = "test", cmd = "echo test", desc = "Test command" }
]

[*.js]
indent_size = 4
]]

    local result = editorconfig.extractExerSection(content)
    assert.is_true(result ~= nil, 'Should extract exer section')
    assert.is_true(result:match('%[exer%]') ~= nil, 'Should contain [exer] header')
    assert.is_true(result:match('acts%s*=') ~= nil, 'Should contain acts definition')
    assert.is_true(not result:match('indent_style'), 'Should not contain non-exer sections')
  end)

  it('should extract [[exer.acts]] array of tables format', function()
    local content = 'root = true\n\n'
      .. '[*]\n'
      .. 'indent_style = space\n\n'
      .. '[[exer.acts]]\n'
      .. 'id = "build"\n'
      .. 'cmd = "gcc main.c"\n'
      .. 'desc = "Build C program"\n\n'
      .. '[[exer.acts]]\n'
      .. 'id = "run"\n'
      .. 'cmd = "./a.out"\n'
      .. 'desc = "Run program"\n\n'
      .. '[*.py]\n'
      .. 'indent_size = 4\n'

    local result = editorconfig.extractExerSection(content)
    assert.is_true(result ~= nil, 'Should extract exer sections')
    assert.is_true(result:match('%[%[exer%.acts%]%]') ~= nil, 'Should contain [[exer.acts]] headers')
    assert.is_true(result:match('id%s*=%s*"build"') ~= nil, 'Should contain first act')
    assert.is_true(result:match('id%s*=%s*"run"') ~= nil, 'Should contain second act')
  end)

  it('should handle mixed formats', function()
    local content = 'root = true\n\n' .. '[exer]\n' .. 'acts = [\n' .. '  { id = "inline", cmd = "echo inline" }\n' .. ']\n\n' .. '[[exer.acts]]\n' .. 'id = "array"\n' .. 'cmd = "echo array"\n'

    local result = editorconfig.extractExerSection(content)
    assert.is_true(result ~= nil, 'Should extract mixed exer sections')
    assert.is_true(result:match('%[exer%]') ~= nil, 'Should contain [exer] header')
    assert.is_true(result:match('%[%[exer%.acts%]%]') ~= nil, 'Should contain [[exer.acts]] header')
  end)

  it('should return nil when no exer section exists', function()
    local content = [[
root = true

[*]
indent_style = space
indent_size = 2
]]

    local result = editorconfig.extractExerSection(content)
    assert.is_nil(result, 'Should return nil when no exer section')
  end)
end)

describe('EditorConfig Integration', function()
  local proj = require('exer.proj')
  local parser = require('exer.proj.parser')

  it('should parse acts from editorconfig format', function()
    local exerContent = [[
[exer]
acts = [
  { id = "test", cmd = "echo test", desc = "Test", when = "lua" },
  { id = "build", cmd = "make", desc = "Build project" }
]
]]

    local result = parser.parseExer(exerContent)
    assert.is_true(result ~= nil, 'Should parse exer content')
    assert.is_true(result.acts ~= nil, 'Should have acts array')
    assert.equals(2, #result.acts, 'Should have 2 acts')
    assert.equals('test', result.acts[1].id, 'First act should be test')
    assert.equals('build', result.acts[2].id, 'Second act should be build')
  end)

  it('should parse [[exer.acts]] format', function()
    local exerContent = '[[exer.acts]]\n'
      .. 'id = "compile"\n'
      .. 'cmd = "gcc ${file} -o ${name}"\n'
      .. 'desc = "Compile C file"\n'
      .. 'when = "c"\n\n'
      .. '[[exer.acts]]\n'
      .. 'id = "run"\n'
      .. 'cmd = "./${name}"\n'
      .. 'desc = "Run compiled program"\n'

    local result = parser.parseExer(exerContent)
    assert.is_true(result ~= nil, 'Should parse exer content')
    assert.is_true(result.acts ~= nil, 'Should have acts array')
    assert.equals(2, #result.acts, 'Should have 2 acts')
    assert.equals('compile', result.acts[1].id, 'First act should be compile')
    assert.equals('run', result.acts[2].id, 'Second act should be run')
  end)
end)
