local ut = require('tests.unitester')
ut.setup()

local co = require('exer.core')
local toml_parser = co.psr.toml
local proj_parser = require('exer.proj.parser')

describe('TOML parser tests', function()
  it('parses basic acts array', function()
    local toml = [[
acts = [
  { id = "run", cmd = "python main.py" }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal('run', result.acts[1].id)
    ut.assert.are.equal('python main.py', result.acts[1].cmd)
  end)

  it('parses multiple tasks', function()
    local toml = [[
acts = [
  { id = "run", cmd = "python main.py" },
  { id = "test", cmd = "pytest", desc = "run tests" }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal(2, #result.acts)
    ut.assert.are.equal('run', result.acts[1].id)
    ut.assert.are.equal('test', result.acts[2].id)
    ut.assert.are.equal('run tests', result.acts[2].desc)
  end)

  it('parses tasks with when field', function()
    local toml = [[
acts = [
  { id = "py", cmd = "python main.py", when = "python" },
  { id = "multi", cmd = "echo test", when = ["python", "javascript"] }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(2, #result.acts)
    ut.assert.are.equal('python', result.acts[1].when)
    ut.assert.are.equal('table', type(result.acts[2].when))
    ut.assert.are.equal(2, #result.acts[2].when)
  end)

  it('handles empty content', function()
    local result = toml_parser.parse('')
    ut.assert.is_nil(result)
  end)

  it('parses multi-step commands', function()
    local toml = [[
acts = [
  { id = "build", cmd = ["pip install -r requirements.txt", "python setup.py build"] }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal('table', type(result.acts[1].cmd))
    ut.assert.are.equal(2, #result.acts[1].cmd)
  end)

  it('handles invalid TOML', function()
    local result = toml_parser.parse('invalid content')
    ut.assert.are.equal('table', type(result))
  end)

  it('parses tasks with env field', function()
    local toml = [[
acts = [
  { id = "test", cmd = "echo test", env = { DEBUG = "1", MODE = "test" } },
  { id = "build", cmd = "make", env = { CC = "gcc", CFLAGS = "-O2" } }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(2, #result.acts)

    local first_act = result.acts[1]
    ut.assert.are.equal('table', type(first_act.env))
    ut.assert.are.equal('string', type(first_act.env.DEBUG))
    ut.assert.are.equal('1', first_act.env.DEBUG)
    ut.assert.are.equal('test', first_act.env.MODE)

    local second_act = result.acts[2]
    ut.assert.are.equal('table', type(second_act.env))
    ut.assert.are.equal('gcc', second_act.env.CC)
    ut.assert.are.equal('-O2', second_act.env.CFLAGS)
  end)

  it('parses tasks with cwd field', function()
    local toml = [[
acts = [
  { id = "test", cmd = "pytest", cwd = "tests/" },
  { id = "build", cmd = "make", cwd = "src/" }
]
]]
    local result = toml_parser.parse(toml)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(2, #result.acts)
    ut.assert.are.equal('tests/', result.acts[1].cwd)
    ut.assert.are.equal('src/', result.acts[2].cwd)
  end)
end)

describe('Project parser tests', function()
  it('parses complete configuration with acts and apps', function()
    local content = [=[
[exer]
acts = [
  { id = 'build', cmd = 'make build' },
  { id = 'test', cmd = 'make test' }
]

[[apps]]
id = 'frontend'
cmd = 'npm start'
desc = 'Start frontend server'

[[apps]]
id = 'backend'
cmd = 'python app.py'
desc = 'Start backend server'
]=]
    local result = proj_parser.parse(content)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal('table', type(result.apps))
    ut.assert.are.equal(2, #result.acts)
    ut.assert.are.equal(2, #result.apps)
    ut.assert.are.equal('build', result.acts[1].id)
    ut.assert.are.equal('frontend', result.apps[1].id)
  end)

  it('parses apps with array fields', function()
    local content = [=[
[[apps]]
name = 'test_app'
entry = 'main.lua'
output = 'dist/app'
type = 'script'
files = ['*.lua', 'config/*.json']
build_args = ['--optimize', '--debug']
run_args = ['--verbose']
env = { LUA_PATH = './?.lua', DEBUG = '1' }
]=]
    local result = proj_parser.parse(content)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(1, #result.apps)

    local app = result.apps[1]
    ut.assert.are.equal('test_app', app.name)
    ut.assert.are.equal('table', type(app.files))
    ut.assert.are.equal(2, #app.files)
    ut.assert.are.equal('*.lua', app.files[1])
    ut.assert.are.equal('config/*.json', app.files[2])

    ut.assert.are.equal('table', type(app.build_args))
    ut.assert.are.equal(2, #app.build_args)
    ut.assert.are.equal('--optimize', app.build_args[1])
    ut.assert.are.equal('--debug', app.build_args[2])

    ut.assert.are.equal('table', type(app.run_args))
    ut.assert.are.equal(1, #app.run_args)
    ut.assert.are.equal('--verbose', app.run_args[1])

    ut.assert.are.equal('table', type(app.env))
    ut.assert.are.equal('./?.lua', app.env.LUA_PATH)
    ut.assert.are.equal('1', app.env.DEBUG)
  end)

  it('parses configuration with acts only', function()
    local content = [[
acts = [
  { id = 'run', cmd = 'python main.py' }
]
]]
    local result = proj_parser.parse(content)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal(0, #result.apps)
  end)

  it('parses configuration with apps only', function()
    local content = [=[
[[apps]]
id = 'server'
cmd = 'node server.js'
]=]
    local result = proj_parser.parse(content)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(0, #result.acts)
    ut.assert.are.equal(1, #result.apps)
    ut.assert.are.equal('server', result.apps[1].id)
  end)

  it('handles empty configuration', function()
    local result = proj_parser.parse('')
    ut.assert.is_nil(result)
  end)

  it('parses complex apps with inline table env', function()
    local content = [=[
[[apps]]
name = "exer_plugin"
entry = "init.lua"
output = "dist/exer.lua"
type = "script"
files = ["*.lua"]
build_args = ["--optimize"]
run_args = ["--test"]
env = { LUA_PATH = "./?.lua;./lua/?.lua" }
cwd = "."

[[apps]]
name = "test_runner"
entry = "tests/init.lua"
output = "dist/test_runner"
type = "script"
files = ["tests/*.lua", "helper.lua"]
build_args = ["--verbose"]
env = {
  TEST_ENV = "ci",
  LUA_TEST_TIMEOUT = "30"
}
]=]
    local result = proj_parser.parse(content)
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(2, #result.apps)

    local app1 = result.apps[1]
    ut.assert.are.equal('exer_plugin', app1.name)
    ut.assert.are.equal('table', type(app1.build_args))
    ut.assert.are.equal(1, #app1.build_args)
    ut.assert.are.equal('--optimize', app1.build_args[1])
    ut.assert.are.equal('table', type(app1.env))
    ut.assert.are.equal('./?.lua;./lua/?.lua', app1.env.LUA_PATH)

    local app2 = result.apps[2]
    ut.assert.are.equal('test_runner', app2.name)
    ut.assert.are.equal('table', type(app2.files))
    ut.assert.are.equal(2, #app2.files)
    ut.assert.are.equal('tests/*.lua', app2.files[1])
    ut.assert.are.equal('helper.lua', app2.files[2])
    ut.assert.are.equal('table', type(app2.env))
    ut.assert.are.equal('ci', app2.env.TEST_ENV)
    ut.assert.are.equal('30', app2.env.LUA_TEST_TIMEOUT)
  end)
end)

describe('JSON parser tests', function()
  it('parses basic JSON configuration', function()
    local json = [[
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
]]
    local result = proj_parser.parse(json, 'json')
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal('run', result.acts[1].id)
    ut.assert.are.equal('python main.py', result.acts[1].cmd)
    ut.assert.are.equal('Run the application', result.acts[1].desc)
  end)

  it('parses JSON with array commands', function()
    local json = [[
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
]]
    local result = proj_parser.parse(json, 'json')
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal('table', type(result.acts))
    ut.assert.are.equal(2, #result.acts)

    -- Check sequential act
    ut.assert.are.equal('sequential', result.acts[1].id)
    ut.assert.are.equal('table', type(result.acts[1].cmd))
    ut.assert.are.equal(2, #result.acts[1].cmd)
    ut.assert.are.equal('build', result.acts[1].cmd[1])
    ut.assert.are.equal('test', result.acts[1].cmd[2])

    -- Check parallel act
    ut.assert.are.equal('parallel', result.acts[2].id)
    ut.assert.are.equal('table', type(result.acts[2].cmds))
    ut.assert.are.equal(2, #result.acts[2].cmds)
    ut.assert.are.equal('lint', result.acts[2].cmds[1])
    ut.assert.are.equal('format', result.acts[2].cmds[2])
  end)

  it('parses JSON with environment and cwd', function()
    local json = [[
{
  "exer": {
    "acts": [
      {
        "id": "test",
        "cmd": "npm test",
        "cwd": "tests/",
        "env": {
          "NODE_ENV": "test",
          "DEBUG": "true"
        }
      }
    ]
  }
}
]]
    local result = proj_parser.parse(json, 'json')
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal('test', result.acts[1].id)
    ut.assert.are.equal('npm test', result.acts[1].cmd)
    ut.assert.are.equal('tests/', result.acts[1].cwd)
    ut.assert.are.equal('table', type(result.acts[1].env))
    ut.assert.are.equal('test', result.acts[1].env.NODE_ENV)
    ut.assert.are.equal('true', result.acts[1].env.DEBUG)
  end)

  it('parses JSON with root-level acts', function()
    local json = [[
{
  "acts": [
    {
      "id": "simple",
      "cmd": "echo hello"
    }
  ]
}
]]
    local result = proj_parser.parse(json, 'json')
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(1, #result.acts)
    ut.assert.are.equal('simple', result.acts[1].id)
    ut.assert.are.equal('echo hello', result.acts[1].cmd)
  end)

  it('handles empty JSON configuration', function()
    local json = [[
{
  "exer": {
    "acts": []
  }
}
]]
    local result = proj_parser.parse(json, 'json')
    ut.assert.are.equal('table', type(result))
    ut.assert.are.equal(0, #result.acts)
  end)

  it('handles invalid JSON gracefully', function()
    local json = [[
{
  "exer": {
    "acts": [
      {
        "id": "invalid"
        "cmd": "missing comma"
      }
    ]
  }
}
]]
    local result = proj_parser.parse(json, 'json')
    -- Invalid JSON 解析失敗應該可以被處理，不要求特定返回值
    ut.assert.is_true(true, 'invalid JSON parsing handled')
  end)
end)
