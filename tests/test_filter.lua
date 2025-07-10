local ut = require('tests.unitester')
ut.setup()

describe('Filetype filter tests', function()
  local proj = require('exer.proj')

  it('filters by single filetype', function()
    local acts = {
      { id = 'py', cmd = 'python', when = 'python' },
      { id = 'js', cmd = 'node', when = 'javascript' },
    }
    local filtered = proj.filterActs(acts, 'python')
    ut.assert.are.equal(1, #filtered)
    ut.assert.are.equal('py', filtered[1].id)
  end)

  it('includes tasks without when clause', function()
    local acts = {
      { id = 'general', cmd = 'echo test' },
      { id = 'py', cmd = 'python', when = 'python' },
    }
    local filtered = proj.filterActs(acts, 'javascript')
    ut.assert.are.equal(1, #filtered)
    ut.assert.are.equal('general', filtered[1].id)
  end)

  it('handles filetype arrays', function()
    local acts = {
      { id = 'multi', cmd = 'echo test', when = { 'python', 'javascript' } },
      { id = 'py', cmd = 'python', when = 'python' },
    }
    local filtered = proj.filterActs(acts, 'javascript')
    ut.assert.are.equal(1, #filtered)
    ut.assert.are.equal('multi', filtered[1].id)
  end)

  it('handles complex filter conditions', function()
    local acts = {
      { id = 'global', cmd = 'make clean' },
      { id = 'py1', cmd = 'python', when = 'python' },
      { id = 'py2', cmd = 'pytest', when = 'python' },
      { id = 'web', cmd = 'npm start', when = { 'javascript', 'typescript' } },
      { id = 'js', cmd = 'node', when = 'javascript' },
    }

    -- Test Python
    local py_filtered = proj.filterActs(acts, 'python')
    ut.assert.are.equal(3, #py_filtered) -- global + py1 + py2

    -- Test TypeScript
    local ts_filtered = proj.filterActs(acts, 'typescript')
    ut.assert.are.equal(2, #ts_filtered) -- global + web

    -- Test non-existent type
    local unknown_filtered = proj.filterActs(acts, 'unknown')
    ut.assert.are.equal(1, #unknown_filtered) -- only global
  end)

  it('handles empty task list', function()
    local filtered = proj.filterActs({}, 'python')
    ut.assert.are.equal(0, #filtered)
  end)

  it('handles nil task list', function()
    local filtered = proj.filterActs(nil, 'python')
    ut.assert.are.equal(0, #filtered)
  end)

  it('handles nil filetype', function()
    local acts = {
      { id = 'general', cmd = 'echo test' },
      { id = 'py', cmd = 'python', when = 'python' },
    }
    local filtered = proj.filterActs(acts, nil)
    ut.assert.are.equal(1, #filtered) -- only tasks without when clause
  end)
end)
