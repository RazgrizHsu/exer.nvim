local ut = require('tests.unitester')
ut.setup()
local proj = require('exer.proj')

describe('Integration tests', function()
  local pathTest = './tmp/proj_integration_test'
  local pathCfg = pathTest .. '/exer.toml'
  local cfgTxt = [[
acts = [
  { id = "run", cmd = "python ${file}", desc = "execute file" },
  { id = "test", cmd = "pytest ${file} -v", when = "python", desc = "run tests" },
  { id = "lint", cmd = "ruff check .", desc = "code linting" },
  { id = "format", cmd = ["black ${file}", "isort ${file}"], when = "python", desc = "formatting" }
]
]]

  ut.itEnv('tests configuration loading', {
    cwd = pathTest,
    files = {
      ['exer.toml'] = cfgTxt,
    },
  }, function()
    local fnd = require('exer.proj.find')
    local config_path = fnd.find()

    ut.assert.is_true(config_path ~= nil, 'should find config file')
    if config_path then ut.assert.matches('exer%.toml$', config_path, 'should find exer.toml') end
  end)

  ut.itEnv('tests get_acts functionality', {
    cwd = pathTest,
    files = {
      ['exer.toml'] = cfgTxt,
    },
  }, function()
    local python_acts = proj.getActs('python')

    ut.assert.are.equal(4, #python_acts) -- run, test, lint, format

    -- Check if contains correct tasks
    local act_ids = {}
    for _, act in ipairs(python_acts) do
      act_ids[act.id] = true
    end
    ut.assert.is_true(act_ids['run'])
    ut.assert.is_true(act_ids['test'])
    ut.assert.is_true(act_ids['lint'])
    ut.assert.is_true(act_ids['format'])
  end)

  ut.itEnv('tests JavaScript task filtering', {
    cwd = pathTest,
    files = {
      ['exer.toml'] = cfgTxt,
    },
  }, function()
    local js_acts = proj.getActs('javascript')

    ut.assert.are.equal(2, #js_acts) -- only general tasks

    local act_ids = {}
    for _, act in ipairs(js_acts) do
      act_ids[act.id] = true
    end
    ut.assert.is_true(act_ids['run'])
    ut.assert.is_true(act_ids['lint'])
    ut.assert.is_nil(act_ids['test']) -- limited to Python
    ut.assert.is_nil(act_ids['format']) -- limited to Python
  end)

  ut.itEnv('tests multi-step commands', {
    cwd = pathTest,
    files = {
      ['exer.toml'] = cfgTxt,
    },
  }, function()
    local python_acts = proj.getActs('python')

    local format_act = nil
    for _, act in ipairs(python_acts) do
      if act.id == 'format' then
        format_act = act
        break
      end
    end

    ut.assert.is_true(format_act ~= nil, 'should find format task')
    ut.assert.are.equal('table', type(format_act.cmd), 'format command should be array')
    ut.assert.are.equal(2, #format_act.cmd, 'should have two steps')
  end)

  ut.itEnv('tests variable expansion in actual tasks', {
    cwd = pathTest,
    currentFile = 'test.py',
    files = {
      ['exer.toml'] = cfgTxt,
      ['test.py'] = 'print("hello")',
    },
  }, function()
    local python_acts = proj.getActs('python')

    for _, act in ipairs(python_acts) do
      if act.id == 'run' then
        local expanded = proj.expandVars(act.cmd)
        ut.assert.matches('python ' .. pathTest .. '/test%.py', expanded, 'run command should expand ${file}')
      elseif act.id == 'test' then
        local expanded = proj.expandVars(act.cmd)
        ut.assert.matches('pytest ' .. pathTest .. '/test%.py', expanded, 'test command should expand ${file}')
      end
    end
  end)
end)
