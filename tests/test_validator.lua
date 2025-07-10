local ut = require('tests.unitester')
ut.setup()
local validator = require('exer.proj.valid')

describe('Configuration validator tests', function()
  it('validates valid configuration', function()
    local config = {
      acts = {
        { id = 'run', cmd = 'python main.py' },
        { id = 'test', cmd = 'pytest', desc = 'test' },
      },
    }
    assert.is_true(validator.validate(config))
  end)

  it('requires acts field', function()
    local config = {}
    assert.is_false(validator.validate(config))
  end)

  it('requires task to have id field', function()
    local config = {
      acts = {
        { cmd = 'python main.py' },
      },
    }
    assert.is_false(validator.validate(config))
  end)

  it('requires task to have cmd field', function()
    local config = {
      acts = {
        { id = 'run' },
      },
    }
    assert.is_false(validator.validate(config))
  end)

  it('validates ID format', function()
    local config = {
      acts = {
        { id = '123invalid', cmd = 'echo test' },
      },
    }
    assert.is_false(validator.validate(config))
  end)

  it('handles duplicate IDs by auto-renaming', function()
    local config = {
      acts = {
        { id = 'run', cmd = 'python main.py' },
        { id = 'run', cmd = 'python test.py' },
      },
    }
    -- Validator automatically renames duplicates, so it should still pass
    assert.is_true(validator.validate(config))
    -- Second task should be renamed to 'run_1'
    assert.equals('run_1', config.acts[2].id)
  end)

  it('validates cmd type', function()
    local config1 = {
      acts = {
        { id = 'run', cmd = '' },
      },
    }
    assert.is_false(validator.validate(config1))

    local config2 = {
      acts = {
        { id = 'run', cmd = {} },
      },
    }
    assert.is_false(validator.validate(config2))
  end)
end)
