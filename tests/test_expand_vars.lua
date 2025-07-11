local ut = require('tests.unitester')
ut.setup()

describe('Variable expansion tests', function()
  local proj = require('exer.proj')

  ut.itEnv('correctly expands ${file}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('python ${file}')
    ut.assert.matches('python /test/project/test%.py', cmd)
  end)

  ut.itEnv('correctly expands ${dir}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('cd ${dir}')
    ut.assert.matches('cd /test/project', cmd)
  end)

  ut.itEnv('correctly expands ${name}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('python ${name}.py')
    ut.assert.matches('python test%.py', cmd)
  end)

  ut.itEnv('correctly expands ${ext}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('echo ${ext}')
    ut.assert.matches('echo py', cmd)
  end)

  ut.itEnv('correctly expands ${stem}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('cp ${stem} backup')
    ut.assert.matches('cp test%.py backup', cmd)
  end)

  ut.itEnv('correctly expands ${root}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('cd ${root}')
    ut.assert.matches('cd /test/project', cmd)
  end)

  ut.itEnv('correctly expands multiple variables', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('python ${file} --output ${dir}/result')
    ut.assert.matches('python /test/project/test%.py', cmd)
    ut.assert.matches('%-%-output /test/project/result', cmd)
  end)

  ut.itEnv('expands array commands', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmds = proj.expandVars({ 'echo ${file}', 'python ${file}' })
    ut.assert.are.equal('table', type(cmds))
    ut.assert.matches('echo /test/project/test%.py', cmds[1])
    ut.assert.matches('python /test/project/test%.py', cmds[2])
  end)

  ut.itEnv('preserves unknown variables', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('echo ${unknown}')
    ut.assert.matches('echo %${unknown}', cmd)
  end)

  ut.itEnv('handles complex commands', {
    cwd = '/test/project',
    currentFile = 'test.c',
    files = { ['test.c'] = 'int main() { return 0; }' },
  }, function()
    local cmd = proj.expandVars('gcc ${name}.c -o ${name} && ./${name}')
    ut.assert.matches('gcc test%.c %-o test', cmd)
    ut.assert.matches('&& %./test', cmd)
  end)

  ut.itEnv('correctly expands ${filename}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('cp ${filename} backup')
    ut.assert.matches('cp test%.py backup', cmd)
  end)

  ut.itEnv('correctly expands ${filetype}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('echo ${filetype}')
    ut.assert.matches('echo python', cmd)
  end)

  ut.itEnv('correctly expands ${fullname}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('gcc ${fullname}.o')
    ut.assert.matches('gcc /test/project/test%.o', cmd)
  end)

  ut.itEnv('correctly expands ${cwd}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('cd ${cwd}')
    ut.assert.matches('cd /test/project', cmd)
  end)

  ut.itEnv('correctly expands ${dirname}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('echo ${dirname}')
    ut.assert.matches('echo project', cmd)
  end)

  ut.itEnv('correctly expands ${servername}', {
    cwd = '/test/project',
    currentFile = 'test.py',
    files = { ['test.py'] = 'print("hello")' },
  }, function()
    local cmd = proj.expandVars('echo ${servername}')
    -- servername 可能為空字串或實際值，但不應該保持 ${servername} 格式
    ut.assert.is_false(cmd:match('%${servername}'), 'variable should be expanded')
  end)
end)
