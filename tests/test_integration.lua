local ut = require('tests.unitester')
ut.setup()
local proj = require('exer.proj')

describe('Integration tests', function()
  local test_dir = './tmp/proj_integration_test'
  local test_config = test_dir .. '/exec.toml'

  it('sets up test environment', function()
    vim.fn.mkdir(test_dir, 'p')
    local content = [[
acts = [
  { id = "run", cmd = "python ${file}", desc = "execute file" },
  { id = "test", cmd = "pytest ${file} -v", when = "python", desc = "run tests" },
  { id = "lint", cmd = "ruff check .", desc = "code linting" },
  { id = "format", cmd = ["black ${file}", "isort ${file}"], when = "python", desc = "formatting" }
]
]]
    vim.fn.writefile(vim.split(content, '\n'), test_config)
    assert.is_true(vim.loop.fs_stat(test_config) ~= nil, 'test config file should exist')
  end)

  it('tests configuration loading', function()
    -- Mock finding config file
    vim.fn.getcwd = function() return test_dir end

    local fnd = require('exer.proj.find')
    local config_path = fnd.find()
    assert.are.equal(test_config, config_path)
  end)

  it('tests get_acts functionality', function()
    -- Clear cache and reset environment
    proj.clearCache()
    vim.fn.getcwd = function() return test_dir end

    -- Test Python tasks
    local python_acts = proj.getActs('python')
    assert.are.equal(4, #python_acts) -- run, test, lint, format

    -- Check if contains correct tasks
    local act_ids = {}
    for _, act in ipairs(python_acts) do
      act_ids[act.id] = true
    end
    assert.is_true(act_ids['run'])
    assert.is_true(act_ids['test'])
    assert.is_true(act_ids['lint'])
    assert.is_true(act_ids['format'])
  end)

  it('tests JavaScript task filtering', function()
    local js_acts = proj.getActs('javascript')
    assert.are.equal(2, #js_acts) -- only general tasks

    local act_ids = {}
    for _, act in ipairs(js_acts) do
      act_ids[act.id] = true
    end
    assert.is_true(act_ids['run'])
    assert.is_true(act_ids['lint'])
    assert.is_nil(act_ids['test']) -- limited to Python
    assert.is_nil(act_ids['format']) -- limited to Python
  end)

  it('tests multi-step commands', function()
    local python_acts = proj.getActs('python')
    local format_act = nil
    for _, act in ipairs(python_acts) do
      if act.id == 'format' then
        format_act = act
        break
      end
    end

    assert.is_true(format_act ~= nil, 'should find format task')
    assert.are.equal('table', type(format_act.cmd), 'format command should be array')
    assert.are.equal(2, #format_act.cmd, 'should have two steps')
  end)

  it('tests variable expansion in actual tasks', function()
    ut.withTestFile('./tmp/proj_integration_test/test.py', 'print("hello")', function()
      ut.testCtx('./tmp/proj_integration_test/test.py', 'python')
      local python_acts = proj.getActs('python')

      for _, act in ipairs(python_acts) do
        if act.id == 'run' then
          local expanded = proj.expandVars(act.cmd)
          assert.matches('python ./tmp/proj_integration_test/test%.py', expanded, 'run command should expand ${file}')
        elseif act.id == 'test' then
          local expanded = proj.expandVars(act.cmd)
          assert.matches('pytest ./tmp/proj_integration_test/test%.py', expanded, 'test command should expand ${file}')
        end
      end
    end)
  end)

  it('cleans up test environment', function()
    vim.fn.delete(test_dir, 'rf')
    assert.is_true(true, 'cleanup completed')
  end)
end)
