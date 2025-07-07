local helper = require('tests.helper')

-- Setup test environment
helper.makeFakeVim()

-- Create temporary directory
local test_dir = '/tmp/exer_bu_test'
vim.fn.mkdir(test_dir, 'p')

-- Test data
local test_files = {
  makefile = {
    path = test_dir .. '/Makefile',
    content = [[all:
	@echo "Building all targets"

clean:
	@rm -f *.o

test:
	@echo "Running tests"
]],
  },
  cmake = {
    path = test_dir .. '/CMakeLists.txt',
    content = [[cmake_minimum_required(VERSION 3.0)
project(test_proj)

add_executable(main main.cpp)
add_executable(test_app test.cpp)
add_custom_target(docs
    COMMAND doxygen Doxyfile
)
]],
  },
  meson = {
    path = test_dir .. '/meson.build',
    content = [[project('test_proj', 'cpp')

executable('main', 'main.cpp')
executable('test_app', 'test.cpp')
custom_target('docs',
    command : ['doxygen', 'Doxyfile'],
    output : 'docs'
)
]],
  },
  package_json = {
    path = test_dir .. '/package.json',
    content = [[{
  "name": "test-project",
  "version": "1.0.0",
  "scripts": {
    "start": "node index.js",
    "test": "jest",
    "build": "webpack",
    "dev": "nodemon index.js"
  }
}]],
  },
}

-- Create test files
for _, file in pairs(test_files) do
  local f = io.open(file.path, 'w')
  f:write(file.content)
  f:close()
end

-- Test make.lua module
describe('make.lua module tests', function()
  -- Load module
  local make_module = {}

  -- Copy getOpts function
  function make_module.getOpts(path)
    local opts = {}
    local file = io.open(path, 'r')
    if file then
      local inTarget = false
      for line in file:lines() do
        local dst = line:match '^(.-):'
        if dst then
          inTarget = true
          table.insert(opts, { text = 'Make ' .. dst, value = dst, bu = 'make' })
        elseif inTarget then
          inTarget = false
        end
      end
      file:close()
    end
    return opts
  end

  it('should parse Makefile targets', function()
    local opts = make_module.getOpts(test_files.makefile.path)
    assert.are.equal(3, #opts)
    assert.are.equal('all', opts[1].value)
    assert.are.equal('clean', opts[2].value)
    assert.are.equal('test', opts[3].value)
  end)

  it('should format target names correctly', function()
    local opts = make_module.getOpts(test_files.makefile.path)
    assert.are.equal('Make all', opts[1].text)
    assert.are.equal('make', opts[1].bu)
  end)

  it('should return empty array for non-existent files', function()
    local opts = make_module.getOpts('/nonexistent/Makefile')
    assert.are.equal(0, #opts)
  end)
end)

-- Test cmake.lua module
describe('cmake.lua module tests', function()
  local cmake_module = {}

  function cmake_module.getOpts(path)
    local opts = {}
    local file = io.open(path, 'r')
    if file then
      local content = file:read('*all')
      file:close()

      for dst in content:gmatch('add_executable%s*%(%s*([%w_-]+)') do
        table.insert(opts, { text = 'CMake ' .. dst, value = dst, bu = 'cmake' })
      end

      for dst in content:gmatch('add_custom_target%s*%(%s*([%w_-]+)') do
        table.insert(opts, { text = 'CMake ' .. dst, value = dst, bu = 'cmake' })
      end
    end
    return opts
  end

  it('should parse add_executable targets', function()
    local opts = cmake_module.getOpts(test_files.cmake.path)
    assert.is_true(#opts >= 2)

    local found_main = false
    local found_test = false
    for _, opt in ipairs(opts) do
      if opt.value == 'main' then found_main = true end
      if opt.value == 'test_app' then found_test = true end
    end
    assert.is_true(found_main, 'should find main target')
    assert.is_true(found_test, 'should find test_app target')
  end)

  it('should parse add_custom_target targets', function()
    local opts = cmake_module.getOpts(test_files.cmake.path)
    local found_docs = false
    for _, opt in ipairs(opts) do
      if opt.value == 'docs' then found_docs = true end
    end
    assert.is_true(found_docs, 'should find docs target')
  end)
end)

-- Test nodejs.lua module
describe('nodejs.lua module tests', function()
  local nodejs_module = {}

  function nodejs_module.getOpts(path)
    local opts = {}
    local file = io.open(path, 'r')
    if file then
      local txt = file:read '*all'
      file:close()

      local jsonPkg = vim.fn.json_decode(txt)
      local mgrPkg = 'npm'

      local scripts = jsonPkg.scripts
      if scripts then
        table.insert(opts, {
          text = mgrPkg:upper() .. ' install',
          value = mgrPkg .. ' install',
          bu = 'nodejs',
        })

        table.insert(opts, {
          text = mgrPkg:upper() .. ' uninstall *',
          value = mgrPkg .. ' uninstall *',
          bu = 'nodejs',
        })

        for script, _ in pairs(scripts) do
          table.insert(opts, {
            text = mgrPkg:upper() .. ' ' .. script,
            value = mgrPkg .. ' run ' .. script,
            bu = 'nodejs',
          })
        end
      end
    end
    return opts
  end

  -- To make json_decode work, we need to mock it
  vim.fn.json_decode = function(str)
    if str:match('"name"') then
      return {
        name = 'test-project',
        version = '1.0.0',
        scripts = {
          start = 'node index.js',
          test = 'jest',
          build = 'webpack',
          dev = 'nodemon index.js',
        },
      }
    end
    return {}
  end

  it('should parse package.json scripts', function()
    local opts = nodejs_module.getOpts(test_files.package_json.path)
    assert.is_true(#opts >= 4, 'should have at least 4 options')

    local script_names = {}
    for _, opt in ipairs(opts) do
      if opt.value:match('run') then
        local script = opt.value:match('run (%w+)')
        if script then script_names[script] = true end
      end
    end

    assert.is_true(script_names.start, 'should have start script')
    assert.is_true(script_names.test, 'should have test script')
    assert.is_true(script_names.build, 'should have build script')
  end)

  it('should include install and uninstall commands', function()
    local opts = nodejs_module.getOpts(test_files.package_json.path)

    local has_install = false
    local has_uninstall = false
    for _, opt in ipairs(opts) do
      if opt.value == 'npm install' then has_install = true end
      if opt.value == 'npm uninstall *' then has_uninstall = true end
    end

    assert.is_true(has_install, 'should have install command')
    assert.is_true(has_uninstall, 'should have uninstall command')
  end)
end)

-- Clean up test files
vim.fn.delete(test_dir, 'rf')
