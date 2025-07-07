---@diagnostic disable: unused-local

local M = {}

M.stats = { passed = 0, failed = 0, total = 0 }

function M.describe(name, func)
  print('\n📋 ' .. name)
  print(string.rep('-', 50))
  func()
end

function M.it(name, func)
  M.stats.total = M.stats.total + 1
  local ok, err = pcall(func)
  if ok then
    M.stats.passed = M.stats.passed + 1
    print('✅ ' .. name)
  else
    M.stats.failed = M.stats.failed + 1
    print('❌ ' .. name)
    print('   錯誤: ' .. tostring(err))
  end
end

M.assert = {
  are = {
    equal = function(expected, actual, msg)
      if expected ~= actual then error(string.format('期望 %s，實際 %s。%s', tostring(expected), tostring(actual), msg or '')) end
    end,
  },
  is_true = function(val, msg)
    if not val then error('期望 true，實際 ' .. tostring(val) .. '。' .. (msg or '')) end
  end,
  is_false = function(val, msg)
    if val then error('期望 false，實際 ' .. tostring(val) .. '。' .. (msg or '')) end
  end,
  is_nil = function(val, msg)
    if val ~= nil then error('Expected nil, got ' .. tostring(val) .. '. ' .. (msg or '')) end
  end,
  matches = function(pattern, str, msg)
    if not str:match(pattern) then error(string.format('String "%s" does not match pattern "%s". %s', str, pattern, msg or '')) end
  end,
  equals = function(expected, actual, msg)
    if expected ~= actual then error(string.format('Expected %s, got %s. %s', tostring(expected), tostring(actual), msg or '')) end
  end,
}

function M.printSummary()
  print('\n📊 Test Results Summary')
  print(string.rep('=', 50))
  print(string.format('Total: %d', M.stats.total))
  print(string.format('✅ Passed: %d', M.stats.passed))
  print(string.format('❌ Failed: %d', M.stats.failed))
  print(string.format('📈 Success Rate: %.1f%%', M.stats.passed / M.stats.total * 100))

  if M.stats.failed == 0 then
    print('\n🎉 All tests passed!')
    return true
  else
    print('\n💥 Some tests failed, please check the error messages above')
    return false
  end
end

function M.makeFakeVim()
  local fake = {
    fn = {
      readfile = function(path)
        local f = io.open(path, 'r')
        if not f then return nil end
        local content = f:read('*all')
        f:close()
        return vim.split(content, '\n')
      end,
      writefile = function(lines, path)
        local f = io.open(path, 'w')
        if not f then return end
        f:write(table.concat(lines, '\n'))
        f:close()
      end,
      mkdir = function(path, mode) os.execute('mkdir -p ' .. path) end,
      delete = function(path, flags)
        if flags == 'rf' then
          os.execute('rm -rf ' .. path)
        else
          os.execute('rm -f ' .. path)
        end
      end,
      getcwd = function() return '/tmp/test_proj' end,
      systemlist = function(cmd) return {} end,
      filereadable = function(path)
        local f = io.open(path, 'r')
        if f then
          f:close()
          return 1
        end
        return 0
      end,
      fnamemodify = function(path, mods)
        if mods == ':t' then
          return path:match('[^/]*$')
        elseif mods == ':p:h' then
          return path:match('(.*/)')
        end
        return path
      end,
      expand = function(expr)
        if expr == '%:p:h' then
          return '/tmp'
        elseif expr == '%:t:r' then
          return 'test'
        elseif expr == '%:e' then
          return 'py'
        elseif expr == '%:t' then
          return 'test.py'
        elseif expr == '%:p:r' then
          return '/tmp/test'
        else
          return expr
        end
      end,
      json_decode = function(str) return {} end,
    },
    api = {
      nvim_buf_get_name = function(ids) return '/tmp/test.py' end,
      nvim_command = function() end,
      nvim_set_current_dir = function(dir) end,
      nvim_get_option_value = function(opt, ctx)
        if opt == 'filetype' then return 'py' end
        return ''
      end,
    },
    v = {
      servername = 'nvim-test',
    },
    loop = {
      fs_stat = function(path)
        local f = io.open(path, 'r')
        if f then
          f:close()
          return { type = 'file' }
        end
        return nil
      end,
    },
    notify = function(msg, level, ops) end,
    log = { levels = { ERROR = 1, INFO = 2 } },
    split = function(str, sep)
      local result = {}
      if not str then return result end
      for part in str:gmatch('[^' .. (sep or '\n') .. ']+') do
        table.insert(result, part)
      end
      return result
    end,
    list_extend = function(list1, list2)
      for _, item in ipairs(list2) do
        table.insert(list1, item)
      end
      return list1
    end,
  }

  return fake
end
return M
