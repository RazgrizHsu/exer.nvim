---@diagnostic disable: lowercase-global

-- Set up Lua path
local script_dir = arg[0]:match('(.*/)')
local base_dir = script_dir .. '../'
-- Add path containing exer modules (adjust for new lua/exer structure)
package.path = base_dir .. 'lua/?.lua;' .. base_dir .. 'lua/?/init.lua;' .. base_dir .. '?.lua;' .. base_dir .. '?/init.lua;' .. (package.path or '')

-- Load test helper module
local helper = require('tests.helper')

-- Set up vim API mock

vim = helper.makeFakeVim()
describe = helper.describe
it = helper.it
assert = helper.assert

-- Load main module (skip because it needs vim API)
-- require('exer')

-- Dynamically scan test files
local function scan_test_files()
  local test_files = {}
  local handle = io.popen('find "' .. script_dir .. '" -name "test_*.lua" -type f')
  if handle then
    for line in handle:lines() do
      local filename = line:match('([^/]+)%.lua$')
      if filename then table.insert(test_files, 'tests.' .. filename) end
    end
    handle:close()
  end
  return test_files
end

print('🚀 Starting test execution...\n')

local test_modules = scan_test_files()
for _, module in ipairs(test_modules) do
  local ok, err = pcall(require, module)
  if not ok then
    print('❌ Failed to load test module: ' .. module)
    print('   Error: ' .. tostring(err))
    helper.stats.failed = helper.stats.failed + 1
    helper.stats.total = helper.stats.total + 1
  end
end

-- Show test results
local success = helper.printSummary()

-- Set exit code based on results
if success then
  os.exit(0)
else
  os.exit(1)
end
