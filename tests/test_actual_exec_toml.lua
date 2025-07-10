local ut = require('tests.unitester')
ut.setup()

describe('Real exec.toml file parsing', function()
  it('reads and parses the actual exec.toml file', function()
    local psr = require('exer.proj.parser')

    local exec_file = 'exec.toml'
    local file_content = vim.fn.readfile(exec_file)
    assert.is_true(#file_content > 0, 'exec.toml should have content')

    local content = table.concat(file_content, '\n')
    local cfg = psr.parse(content)

    assert.is_true(cfg ~= nil, 'should parse exec.toml')
    assert.is_true(cfg.acts ~= nil, 'should have acts')
    assert.is_true(cfg.apps ~= nil, 'should have apps')
    assert.is_true(#cfg.acts > 0, 'should have some acts')
    assert.is_true(#cfg.apps > 0, 'should have some apps')

    local has_lua_run = false
    for _, act in ipairs(cfg.acts) do
      if act.id == 'lua_run' then
        has_lua_run = true
        assert.are.equal('lua ${file}', act.cmd)
        break
      end
    end
    assert.is_true(has_lua_run, 'should have lua_run task')

    local has_hello_world = false
    for _, app in ipairs(cfg.apps) do
      if app.name == 'hello_world' then
        has_hello_world = true
        break
      end
    end
    assert.is_true(has_hello_world, 'should have hello_world app')
  end)
end)
