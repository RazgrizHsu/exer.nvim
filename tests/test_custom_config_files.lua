local ut = require('tests.unitester')
ut.setup()

describe('Custom config files', function()
  local config = require('exer.config')
  local find = require('exer.proj.find')
  local co = require('exer.core')

  ut.itEnv('should allow custom config files in setup', {
    config = {
      config_files = {
        'my-config.toml',
        'config/exec.toml',
        { path = 'Cargo.toml', section = 'package.metadata.exec' },
      },
    },
  }, function()
    local config = require('exer.config')
    local opts = config.get()
    ut.assert.are.equal('table', type(opts.config_files))
    ut.assert.are.equal(3, #opts.config_files)
    ut.assert.are.equal('my-config.toml', opts.config_files[1])
    ut.assert.are.equal('config/exec.toml', opts.config_files[2])
    ut.assert.are.equal('table', type(opts.config_files[3]))
    ut.assert.are.equal('Cargo.toml', opts.config_files[3].path)
    ut.assert.are.equal('package.metadata.exec', opts.config_files[3].section)
  end)

  ut.itEnv('should use default config when no custom files specified', {
    config = {},
  }, function()
    local config = require('exer.config')
    local opts = config.get()
    ut.assert.are.equal(nil, opts.config_files)
  end)

  ut.itEnv('should handle string config files', {
    cwd = '/test/project',
    config = {
      config_files = { 'my-config.toml' },
    },
    files = {
      ['my-config.toml'] = '',
    },
  }, function()
    local find = require('exer.proj.find')
    local result = find.find()
    ut.assert.are.equal('/test/project/my-config.toml', result)
  end)

  ut.itEnv('should handle table config files with sections', {
    cwd = '/test/project',
    config = {
      config_files = {
        { path = 'Cargo.toml', section = 'package.metadata.exec' },
      },
    },
    files = {
      ['Cargo.toml'] = {
        '[package]',
        'name = "test"',
        '',
        '[package.metadata.exec]',
        'acts = [',
        '  { id = "test", cmd = "cargo run" }',
        ']',
      },
    },
  }, function()
    local find = require('exer.proj.find')
    local result = find.find()
    ut.assert.are.equal('/test/project/Cargo.toml', result)
  end)

  ut.itEnv('should handle absolute paths', {
    cwd = '/test/project',
    config = {
      config_files = { '/absolute/path/my-config.toml' },
    },
    mockFiles = {
      ['/absolute/path/my-config.toml'] = '',
    },
  }, function()
    local find = require('exer.proj.find')
    local result = find.find()
    ut.assert.are.equal('/absolute/path/my-config.toml', result)
  end)

  ut.itEnv('should respect order of config files', {
    cwd = '/test/project',
    config = {
      config_files = { 'first.toml', 'second.toml' },
    },
    files = {
      -- Second file exists but first should be found first
      ['second.toml'] = '',
    },
  }, function()
    local find = require('exer.proj.find')
    local result = find.find()
    ut.assert.are.equal('/test/project/second.toml', result)
  end)
end)
