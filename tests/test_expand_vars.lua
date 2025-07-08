-- Variable expansion tests
local helper = require('tests.helper')

---@diagnostic disable-next-line: lowercase-global
vim = helper.makeFakeVim()
local proj = require('exer.proj')

describe('Variable expansion tests', function()
  it('correctly expands ${file}', function()
    local cmd = proj.expandVars('python ${file}')
    assert.matches('/tmp/test%.py', cmd)
  end)

  it('correctly expands ${dir}', function()
    local cmd = proj.expandVars('cd ${dir}')
    assert.matches('/tmp', cmd)
  end)

  it('correctly expands ${name}', function()
    local cmd = proj.expandVars('python ${name}.py')
    assert.matches('test%.py', cmd)
  end)

  it('correctly expands ${ext}', function()
    local cmd = proj.expandVars('echo ${ext}')
    assert.matches('py', cmd)
  end)

  it('correctly expands ${stem}', function()
    local cmd = proj.expandVars('cp ${stem} backup')
    assert.matches('test%.py', cmd)
  end)

  it('correctly expands ${root}', function()
    local cmd = proj.expandVars('cd ${root}')
    assert.matches('/tmp/test_proj', cmd)
  end)

  it('correctly expands multiple variables', function()
    local cmd = proj.expandVars('python ${file} --output ${dir}/result')
    assert.matches('/tmp/test%.py', cmd)
    assert.matches('/tmp/result', cmd)
  end)

  it('expands array commands', function()
    local cmds = proj.expandVars({ 'echo ${file}', 'python ${file}' })
    assert.are.equal('string', type(cmds))
    assert.matches('/tmp/test%.py', cmds)
    assert.matches('&&', cmds)
  end)

  it('preserves unknown variables', function()
    local cmd = proj.expandVars('echo ${unknown}')
    assert.matches('${unknown}', cmd)
  end)

  it('handles complex commands', function()
    local cmd = proj.expandVars('gcc ${name}.c -o ${name} && ./${name}')
    assert.matches('gcc test%.c %-o test && %./test', cmd)
  end)

  it('correctly expands ${filename}', function()
    local cmd = proj.expandVars('cp ${filename} backup')
    assert.matches('test%.py', cmd)
  end)

  it('correctly expands ${filetype}', function()
    local cmd = proj.expandVars('echo ${filetype}')
    assert.matches('py', cmd)
  end)

  it('correctly expands ${fullname}', function()
    local cmd = proj.expandVars('gcc ${fullname}.o')
    assert.matches('/tmp/test%.o', cmd)
  end)

  it('correctly expands ${cwd}', function()
    local cmd = proj.expandVars('cd ${cwd}')
    assert.matches('/tmp/test_proj', cmd)
  end)

  it('correctly expands ${dirname}', function()
    local cmd = proj.expandVars('echo ${dirname}')
    assert.matches('test_proj', cmd)
  end)

  it('correctly expands ${servername}', function()
    local cmd = proj.expandVars('echo ${servername}')
    assert.matches('nvim%-test', cmd)
  end)
end)
