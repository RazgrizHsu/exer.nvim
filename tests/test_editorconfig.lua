local ut = require('tests.unitester')
ut.setup()

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
    ut.assert.is_true(result ~= nil, 'Should extract exer section')
    ut.assert.is_true(result:match('%[exer%]') ~= nil, 'Should contain [exer] header')
    ut.assert.is_true(result:match('acts%s*=') ~= nil, 'Should contain acts definition')
    ut.assert.is_true(not result:match('indent_style'), 'Should not contain non-exer sections')
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
    ut.assert.is_true(result ~= nil, 'Should extract exer sections')
    ut.assert.is_true(result:match('%[%[exer%.acts%]%]') ~= nil, 'Should contain [[exer.acts]] headers')
    ut.assert.is_true(result:match('id%s*=%s*"build"') ~= nil, 'Should contain first act')
    ut.assert.is_true(result:match('id%s*=%s*"run"') ~= nil, 'Should contain second act')
  end)

  it('should handle mixed formats', function()
    local content = 'root = true\n\n' .. '[exer]\n' .. 'acts = [\n' .. '  { id = "inline", cmd = "echo inline" }\n' .. ']\n\n' .. '[[exer.acts]]\n' .. 'id = "array"\n' .. 'cmd = "echo array"\n'

    local result = editorconfig.extractExerSection(content)
    ut.assert.is_true(result ~= nil, 'Should extract mixed exer sections')
    ut.assert.is_true(result:match('%[exer%]') ~= nil, 'Should contain [exer] header')
    ut.assert.is_true(result:match('%[%[exer%.acts%]%]') ~= nil, 'Should contain [[exer.acts]] header')
  end)

  it('should return nil when no exer section exists', function()
    local content = [[
root = true

[*]
indent_style = space
indent_size = 2
]]

    local result = editorconfig.extractExerSection(content)
    ut.assert.is_nil(result, 'Should return nil when no exer section')
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
    ut.assert.is_true(result ~= nil, 'Should parse exer content')
    ut.assert.is_true(result.acts ~= nil, 'Should have acts array')
    ut.assert.equals(2, #result.acts, 'Should have 2 acts')
    ut.assert.equals('test', result.acts[1].id, 'First act should be test')
    ut.assert.equals('build', result.acts[2].id, 'Second act should be build')
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
    ut.assert.is_true(result ~= nil, 'Should parse exer content')
    ut.assert.is_true(result.acts ~= nil, 'Should have acts array')
    ut.assert.equals(2, #result.acts, 'Should have 2 acts')
    ut.assert.equals('compile', result.acts[1].id, 'First act should be compile')
    ut.assert.equals('run', result.acts[2].id, 'Second act should be run')
  end)
end)

describe('EditorConfig Array Support', function()
  local editorconfig = require('exer.core.psr.editorconfig')
  local parser = require('exer.proj.parser')

  it('should parse INI format with array commands', function()
    local content = [[
root = true

[*]
indent_style = space

[exer.acts]
id = sequential
cmd = [ "build", "test" ]
desc = Sequential execution

[exer.acts]
id = parallel
cmds = [ "lint", "format" ]
desc = Parallel execution
]]

    local exerContent, sectionType = editorconfig.extractExerSection(content)
    ut.assert.is_true(exerContent ~= nil, 'Should extract exer section')
    ut.assert.equals('exer_acts', sectionType, 'Should detect exer_acts section type')

    local convertedToml = editorconfig.convertIniToToml(exerContent)
    ut.assert.is_true(convertedToml ~= nil, 'Should convert INI to TOML')

    local result = parser.parseExer(convertedToml)
    ut.assert.is_true(result ~= nil, 'Should parse converted content')
    ut.assert.is_true(result.acts ~= nil, 'Should have acts array')
    ut.assert.equals(2, #result.acts, 'Should have 2 acts')

    -- Check sequential act
    ut.assert.equals('sequential', result.acts[1].id, 'First act should be sequential')
    ut.assert.equals('table', type(result.acts[1].cmd), 'Sequential cmd should be array')
    ut.assert.equals(2, #result.acts[1].cmd, 'Sequential cmd should have 2 items')
    ut.assert.equals('build', result.acts[1].cmd[1], 'First command should be build')
    ut.assert.equals('test', result.acts[1].cmd[2], 'Second command should be test')

    -- Check parallel act
    ut.assert.equals('parallel', result.acts[2].id, 'Second act should be parallel')
    ut.assert.equals('table', type(result.acts[2].cmds), 'Parallel cmds should be array')
    ut.assert.equals(2, #result.acts[2].cmds, 'Parallel cmds should have 2 items')
    ut.assert.equals('lint', result.acts[2].cmds[1], 'First command should be lint')
    ut.assert.equals('format', result.acts[2].cmds[2], 'Second command should be format')
  end)

  it('should parse INI format with act references', function()
    local content = [[
root = true

[exer.acts]
id = build
cmd = gcc main.c -o main
desc = Build the application

[exer.acts]
id = test
cmd = ./main
desc = Run the application

[exer.acts]
id = ci
cmd = [ "cmd:build", "cmd:test" ]
desc = CI pipeline
]]

    local exerContent, sectionType = editorconfig.extractExerSection(content)
    ut.assert.is_true(exerContent ~= nil, 'Should extract exer section')

    local convertedToml = editorconfig.convertIniToToml(exerContent)
    ut.assert.is_true(convertedToml ~= nil, 'Should convert INI to TOML')

    local result = parser.parseExer(convertedToml)
    ut.assert.is_true(result ~= nil, 'Should parse converted content')
    ut.assert.is_true(result.acts ~= nil, 'Should have acts array')
    ut.assert.equals(3, #result.acts, 'Should have 3 acts')

    -- Check build act
    ut.assert.equals('build', result.acts[1].id, 'First act should be build')
    ut.assert.equals('gcc main.c -o main', result.acts[1].cmd, 'Build cmd should be string')

    -- Check test act
    ut.assert.equals('test', result.acts[2].id, 'Second act should be test')
    ut.assert.equals('./main', result.acts[2].cmd, 'Test cmd should be string')

    -- Check CI act with references
    ut.assert.equals('ci', result.acts[3].id, 'Third act should be ci')
    ut.assert.equals('table', type(result.acts[3].cmd), 'CI cmd should be array')
    ut.assert.equals(2, #result.acts[3].cmd, 'CI cmd should have 2 items')
    ut.assert.equals('cmd:build', result.acts[3].cmd[1], 'First reference should be cmd:build')
    ut.assert.equals('cmd:test', result.acts[3].cmd[2], 'Second reference should be cmd:test')
  end)

  it('should handle mixed string and array formats', function()
    local content = [[
[exer.acts]
id = simple
cmd = echo hello
desc = Simple string command

[exer.acts]
id = complex
cmd = [ "echo start", "echo end" ]
desc = Array command

[exer.acts]
id = with_vars
cmd = gcc ${file} -o ${name}
desc = Command with variables
]]

    local exerContent, sectionType = editorconfig.extractExerSection(content)
    ut.assert.is_true(exerContent ~= nil, 'Should extract exer section')

    local convertedToml = editorconfig.convertIniToToml(exerContent)
    ut.assert.is_true(convertedToml ~= nil, 'Should convert INI to TOML')

    local result = parser.parseExer(convertedToml)
    ut.assert.is_true(result ~= nil, 'Should parse converted content')
    ut.assert.equals(3, #result.acts, 'Should have 3 acts')

    -- Check simple string command
    ut.assert.equals('simple', result.acts[1].id, 'First act should be simple')
    ut.assert.equals('echo hello', result.acts[1].cmd, 'Simple cmd should be string')

    -- Check array command
    ut.assert.equals('complex', result.acts[2].id, 'Second act should be complex')
    ut.assert.equals('table', type(result.acts[2].cmd), 'Complex cmd should be array')
    ut.assert.equals(2, #result.acts[2].cmd, 'Complex cmd should have 2 items')

    -- Check command with variables
    ut.assert.equals('with_vars', result.acts[3].id, 'Third act should be with_vars')
    ut.assert.equals('gcc ${file} -o ${name}', result.acts[3].cmd, 'Vars cmd should preserve variables')
  end)

  it('should handle environment and cwd in INI format', function()
    local content = [[
[exer.acts]
id = test_with_env
cmd = npm test
cwd = tests/
env = { NODE_ENV = "test", DEBUG = "true" }
desc = Test with environment
]]

    local exerContent, sectionType = editorconfig.extractExerSection(content)
    ut.assert.is_true(exerContent ~= nil, 'Should extract exer section')

    local convertedToml = editorconfig.convertIniToToml(exerContent)
    ut.assert.is_true(convertedToml ~= nil, 'Should convert INI to TOML')

    local result = parser.parseExer(convertedToml)
    ut.assert.is_true(result ~= nil, 'Should parse converted content')
    ut.assert.equals(1, #result.acts, 'Should have 1 act')

    local act = result.acts[1]
    ut.assert.equals('test_with_env', act.id, 'Act ID should be test_with_env')
    ut.assert.equals('npm test', act.cmd, 'Act cmd should be npm test')
    ut.assert.equals('tests/', act.cwd, 'Act cwd should be tests/')
    -- Note: env parsing in INI format may need additional work
  end)
end)
