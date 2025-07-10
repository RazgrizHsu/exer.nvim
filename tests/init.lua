_G.utmode = nil
_G.ut_name_filter = nil

local i = 1
while i <= #arg do
  local param = arg[i]
  if param == '-eo' then
    _G.utmode = '-eo'
    i = i + 1
  elseif param == '-n' then
    if i + 1 <= #arg then
      _G.ut_name_filter = arg[i + 1]
      i = i + 2
    else
      print('Error: -n requires a pattern argument')
      os.exit(1)
    end
  else
    i = i + 1
  end
end

local dirSct = arg[0]:match('(.*/)')
local dirBse = dirSct .. '../'
package.path = dirBse .. 'lua/?.lua;' .. dirBse .. 'lua/?/init.lua;' .. dirBse .. '?.lua;' .. dirBse .. '?/init.lua;' .. (package.path or '')

local ut = require('tests.unitester')

ut.setup()

-- Dynamically scan test files
local function scan()
  local fss = {}
  local hnd = io.popen('find "' .. dirSct .. '" -name "test_*.lua" -type f')
  if hnd then
    for line in hnd:lines() do
      local fnm = line:match('([^/]+)%.lua$')
      if fnm then table.insert(fss, 'tests.' .. fnm) end
    end
    hnd:close()
  end
  return fss
end

print('🚀 Starting test execution...\n')

local tmods = scan()
for _, mod in ipairs(tmods) do
  local ok, err = pcall(require, mod)
  if not ok then
    print('❌ Failed to load test module: ' .. mod)
    print('   Error: ' .. tostring(err))
    ut.stats.failed = ut.stats.failed + 1
    ut.stats.total = ut.stats.total + 1
  end
end

local ok = ut.summary()
if ok then
  os.exit(0)
else
  os.exit(1)
end
