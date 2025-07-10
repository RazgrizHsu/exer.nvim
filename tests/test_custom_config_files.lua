local ut = require('tests.unitester')
ut.setup()

describe('Custom config files', function()
  local config = require('exer.config')
  local find = require('exer.proj.find')
  local co = require('exer.core')

  it('should allow custom config files in setup', function()
    config.setup({
      config_files = {
        'my-config.toml',
        'config/exec.toml',
        { path = 'Cargo.toml', section = 'package.metadata.exec' },
      },
    })

    local opts = config.get()
    assert.are.equal('table', type(opts.config_files))
    assert.are.equal(3, #opts.config_files)
    assert.are.equal('my-config.toml', opts.config_files[1])
    assert.are.equal('config/exec.toml', opts.config_files[2])
    assert.are.equal('table', type(opts.config_files[3]))
    assert.are.equal('Cargo.toml', opts.config_files[3].path)
    assert.are.equal('package.metadata.exec', opts.config_files[3].section)
  end)

  it('should use default config when no custom files specified', function()
    config.setup({})

    local opts = config.get()
    assert.are.equal(nil, opts.config_files)
  end)

  it('should handle string config files', function()
    -- Mock getRoot and fileExists
    local originalGetRoot = co.io.getRoot
    local originalFileExists = co.io.fileExists

    co.io.getRoot = function() return '/test/project' end
    co.io.fileExists = function(path) return path == '/test/project/my-config.toml' end

    config.setup({
      config_files = { 'my-config.toml' },
    })

    local result = find.find()
    assert.are.equal('/test/project/my-config.toml', result)

    -- Restore original functions
    co.io.getRoot = originalGetRoot
    co.io.fileExists = originalFileExists
  end)

  it('should handle table config files with sections', function()
    -- Mock getRoot and checkEmbedCfg
    local originalGetRoot = co.io.getRoot
    local originalFileExists = co.io.fileExists

    co.io.getRoot = function() return '/test/project' end
    co.io.fileExists = function(path) return path == '/test/project/Cargo.toml' end

    -- Mock file reading to simulate embedded config
    local originalReadFile = vim.fn.readfile
    vim.fn.readfile = function(path)
      if path == '/test/project/Cargo.toml' then
        return {
          '[package]',
          'name = "test"',
          '',
          '[package.metadata.exec]',
          'acts = [',
          '  { id = "test", cmd = "cargo run" }',
          ']',
        }
      end
      return {}
    end

    config.setup({
      config_files = {
        { path = 'Cargo.toml', section = 'package.metadata.exec' },
      },
    })

    local result = find.find()
    assert.are.equal('/test/project/Cargo.toml', result)

    -- Restore original functions
    co.io.getRoot = originalGetRoot
    co.io.fileExists = originalFileExists
    vim.fn.readfile = originalReadFile
  end)

  it('should handle absolute paths', function()
    local originalGetRoot = co.io.getRoot
    local originalFileExists = co.io.fileExists

    co.io.getRoot = function() return '/test/project' end
    co.io.fileExists = function(path) return path == '/absolute/path/my-config.toml' end

    config.setup({
      config_files = { '/absolute/path/my-config.toml' },
    })

    local result = find.find()
    assert.are.equal('/absolute/path/my-config.toml', result)

    -- Restore original functions
    co.io.getRoot = originalGetRoot
    co.io.fileExists = originalFileExists
  end)

  it('should respect order of config files', function()
    local originalGetRoot = co.io.getRoot
    local originalFileExists = co.io.fileExists

    co.io.getRoot = function() return '/test/project' end
    co.io.fileExists = function(path)
      -- Second file exists but first should be found first
      return path == '/test/project/second.toml'
    end

    config.setup({
      config_files = { 'first.toml', 'second.toml' },
    })

    local result = find.find()
    assert.are.equal('/test/project/second.toml', result)

    -- Restore original functions
    co.io.getRoot = originalGetRoot
    co.io.fileExists = originalFileExists
  end)
end)
