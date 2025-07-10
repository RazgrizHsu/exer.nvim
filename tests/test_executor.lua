local ut = require('tests.unitester')
ut.setup()

describe('Executor System Tests', function()
  local executor, mockTasks

  -- Mock core modules
  local co = require('exer.core')
  co.log = {
    debug = function(msg, mod) end,
    warn = function(msg, mod) end,
  }

  co.utils = {
    msg = function(msg, level) end,
  }

  -- Mock runner to capture tasks
  local function mockRun(config) table.insert(mockTasks, config) end

  -- Override the runner module
  package.loaded['exer.core.runner'] = {
    run = mockRun,
  }

  executor = require('exer.proj.executor')

  it('executes simple act correctly', function()
    mockTasks = {}

    local act = {
      id = 'simple',
      cmd = 'echo hello',
      cwd = './tmp',
      env = { TEST = 'true' },
    }

    executor.executeAct(act, {})

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] simple', mockTasks[1].name)
    assert.are.equal('echo hello', mockTasks[1].cmd)
    assert.are.equal('./tmp', mockTasks[1].cwd)
    assert.are.equal('true', mockTasks[1].env.TEST)
  end)

  it('executes sequential array commands', function()
    mockTasks = {}

    local act = {
      id = 'sequential',
      cmd = { 'echo start', 'echo middle', 'echo end' },
      cwd = './tmp',
    }

    executor.executeAct(act, {})

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] sequential', mockTasks[1].name)
    assert.are.equal('echo start && echo middle && echo end', mockTasks[1].cmd)
    assert.are.equal('./tmp', mockTasks[1].cwd)
  end)

  it('executes parallel array commands', function()
    mockTasks = {}

    local act = {
      id = 'parallel',
      cmds = { 'echo task1', 'echo task2', 'echo task3' },
      cwd = './tmp',
    }

    executor.executeAct(act, {})

    assert.are.equal(3, #mockTasks)
    assert.are.equal('[proj] parallel (1/3)', mockTasks[1].name)
    assert.are.equal('echo task1', mockTasks[1].cmd)
    assert.are.equal('[proj] parallel (2/3)', mockTasks[2].name)
    assert.are.equal('echo task2', mockTasks[2].cmd)
    assert.are.equal('[proj] parallel (3/3)', mockTasks[3].name)
    assert.are.equal('echo task3', mockTasks[3].cmd)
  end)

  it('resolves act references in sequential mode', function()
    mockTasks = {}

    local allActs = {
      { id = 'build', cmd = 'gcc main.c -o main', cwd = 'src' },
      { id = 'test', cmd = 'npm test', cwd = 'tests' },
      { id = 'ci', cmd = { 'cmd:build', 'cmd:test' }, cwd = './tmp' },
    }

    executor.executeAct(allActs[3], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] ci', mockTasks[1].name)
    assert.are.equal('gcc main.c -o main && npm test', mockTasks[1].cmd)
    assert.are.equal('./tmp', mockTasks[1].cwd)
  end)

  it('resolves act references in parallel mode', function()
    mockTasks = {}

    local allActs = {
      { id = 'lint', cmd = 'eslint src/', cwd = 'src' },
      { id = 'format', cmd = 'prettier --write src/', cwd = 'src' },
      { id = 'quality', cmds = { 'cmd:lint', 'cmd:format' }, cwd = './tmp' },
    }

    executor.executeAct(allActs[3], allActs)

    assert.are.equal(2, #mockTasks)
    assert.are.equal('[proj] lint', mockTasks[1].name)
    assert.are.equal('eslint src/', mockTasks[1].cmd)
    assert.are.equal('src', mockTasks[1].cwd)
    assert.are.equal('[proj] format', mockTasks[2].name)
    assert.are.equal('prettier --write src/', mockTasks[2].cmd)
    assert.are.equal('src', mockTasks[2].cwd)
  end)

  it('handles mixed direct commands and references', function()
    mockTasks = {}

    local allActs = {
      { id = 'build', cmd = 'gcc main.c -o main' },
      { id = 'deploy', cmd = { 'cmd:build', 'echo "deploying"', 'scp main server:/bin/' } },
    }

    executor.executeAct(allActs[2], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] deploy', mockTasks[1].name)
    assert.are.equal('gcc main.c -o main && echo "deploying" && scp main server:/bin/', mockTasks[1].cmd)
  end)

  it('handles nested act references', function()
    mockTasks = {}

    local allActs = {
      { id = 'compile', cmd = 'gcc main.c -o main' },
      { id = 'test', cmd = './main' },
      { id = 'build', cmd = { 'cmd:compile', 'cmd:test' } },
      { id = 'release', cmd = { 'cmd:build', 'echo "releasing"' } },
    }

    executor.executeAct(allActs[4], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] release', mockTasks[1].name)
    assert.are.equal('gcc main.c -o main && ./main && echo "releasing"', mockTasks[1].cmd)
  end)

  it('handles act references with array commands', function()
    mockTasks = {}

    local allActs = {
      { id = 'setup', cmd = { 'mkdir -p build', 'cd build' } },
      { id = 'compile', cmd = 'gcc ../main.c -o main' },
      { id = 'full_build', cmd = { 'cmd:setup', 'cmd:compile' } },
    }

    executor.executeAct(allActs[3], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] full_build', mockTasks[1].name)
    assert.are.equal('mkdir -p build && cd build && gcc ../main.c -o main', mockTasks[1].cmd)
  end)

  it('handles environment and cwd inheritance', function()
    mockTasks = {}

    local allActs = {
      { id = 'test', cmd = 'npm test', cwd = 'tests', env = { NODE_ENV = 'test' } },
      { id = 'e2e', cmd = { 'cmd:test', 'echo "e2e done"' }, cwd = './tmp', env = { DEBUG = 'true' } },
    }

    executor.executeAct(allActs[2], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] e2e', mockTasks[1].name)
    assert.are.equal('npm test && echo "e2e done"', mockTasks[1].cmd)
    assert.are.equal('./tmp', mockTasks[1].cwd)
    assert.are.equal('true', mockTasks[1].env.DEBUG)
  end)

  it('handles non-existent act reference', function()
    mockTasks = {}

    local allActs = {
      { id = 'valid', cmd = 'echo valid' },
      { id = 'invalid_ref', cmd = { 'cmd:valid', 'cmd:nonexistent' } },
    }

    executor.executeAct(allActs[2], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] invalid_ref', mockTasks[1].name)
    assert.are.equal('echo valid', mockTasks[1].cmd)
  end)

  it('expands variables in referenced acts', function()
    mockTasks = {}

    -- Mock variable expansion
    local vars = require('exer.proj.vars')
    local originalExpandVars = vars.expandVars
    vars.expandVars = function(cmd)
      if type(cmd) == 'string' then
        return cmd:gsub('${file}', '/tmp/test.c'):gsub('${name}', 'test')
      elseif type(cmd) == 'table' then
        local result = {}
        for _, c in ipairs(cmd) do
          table.insert(result, c:gsub('${file}', '/tmp/test.c'):gsub('${name}', 'test'))
        end
        return result
      end
      return cmd
    end

    local allActs = {
      { id = 'compile', cmd = 'gcc ${file} -o ${name}' },
      { id = 'run', cmd = './${name}' },
      { id = 'build_and_run', cmd = { 'cmd:compile', 'cmd:run' } },
    }

    executor.executeAct(allActs[3], allActs)

    assert.are.equal(1, #mockTasks)
    assert.are.equal('[proj] build_and_run', mockTasks[1].name)
    assert.are.equal('gcc /tmp/test.c -o test && ./test', mockTasks[1].cmd)

    -- Restore original function
    vars.expandVars = originalExpandVars
  end)
end)
