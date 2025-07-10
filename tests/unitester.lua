local M = {}

M.stats = { passed = 0, failed = 0, total = 0 }
M.ctx = { filepath = './tmp/test.py', filetype = 'py' }

function M.describe(name, func)
  if not utmode then
    print('\n📋 ' .. name)
    print(string.rep('-', 50))
  end
  func()
end

function M.it(name, func)
  M.stats.total = M.stats.total + 1
  local ok, err = pcall(func)
  if ok then
    M.stats.passed = M.stats.passed + 1
    if not utmode then print('✅ ' .. name) end
  else
    M.stats.failed = M.stats.failed + 1
    print('❌ ' .. name)
    print('   Error: ' .. tostring(err))
    print('')
  end
end

M.assert = {
  are = {
    equal = function(expected, actual, msg)
      if expected ~= actual then error(string.format('expect `%s`，actual `%s`.  %s', tostring(expected), tostring(actual), msg or ''), 2) end
    end,
  },
  is_true = function(val, msg)
    if not val then error('expect true，actual ' .. tostring(val) .. '。' .. (msg or ''), 2) end
  end,
  is_false = function(val, msg)
    if val then error('expect false，actual ' .. tostring(val) .. '。' .. (msg or ''), 2) end
  end,
  is_nil = function(val, msg)
    if val ~= nil then error('Expected nil, got ' .. tostring(val) .. '. ' .. (msg or ''), 2) end
  end,
  matches = function(pattern, str, msg)
    if not str:match(pattern) then error(string.format('String "%s" does not match pattern "%s". %s', str, pattern, msg or ''), 2) end
  end,
  equals = function(expected, actual, msg)
    if expected ~= actual then error(string.format('Expected %s, got %s. %s', tostring(expected), tostring(actual), msg or ''), 2) end
  end,
}

function M.summary()
  print('')
  print(string.rep('=', 50))
  print('📊 Test Results Summary')
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

function M.setup()
  local dirSct = arg[0]:match('(.*/)')
  local dirBse = dirSct .. '../'
  package.path = dirBse .. 'lua/?.lua;' .. dirBse .. 'lua/?/init.lua;' .. dirBse .. '?.lua;' .. dirBse .. '?/init.lua;' .. (package.path or '')

  -- package.path = vim.fn.getcwd() .. '/lua/?.lua;' .. package.path

  -- Force reload of proj modules to use new vim instance
  package.loaded['exer.proj.vars'] = nil
  package.loaded['exer.proj'] = nil

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
      getcwd = function()
        local filepath = M.ctx.filepath
        return filepath:match('(.*)/[^/]*$') or '.'
      end,
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
        elseif mods == ':t:r' then
          local name = path:match('[^/]*$')
          return name:match('(.*)%.[^%.]*$') or name
        end
        return path
      end,
      expand = function(expr)
        local fp = M.ctx.filepath
        if expr == '%:p:h' then
          return fp:match('(.*)/[^/]*$') or '.'
        elseif expr == '%:t:r' then
          local name = fp:match('[^/]*$')
          return name:match('(.*)%.[^%.]*$') or name
        elseif expr == '%:e' then
          return fp:match('%.([^%.]*)$') or ''
        elseif expr == '%:t' then
          return fp:match('[^/]*$') or ''
        elseif expr == '%:p:r' then
          return fp:match('(.*)%.[^%.]*$') or fp
        elseif expr == '%:p' then
          return fp
        elseif expr == '%' then
          return fp
        else
          return expr
        end
      end,
      json_decode = function(str)
        -- Simple JSON parser for testing
        if not str or str == '' then return {} end

        -- Try to use a simple JSON parser
        local ok, result = pcall(function()
          -- Remove whitespace and newlines
          str = str:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')

          -- Very basic JSON parsing (only for test cases)
          if str == '{}' then return {} end

          -- Try to parse simple structures
          if str:match('^{.*}$') then
            local obj = {}

            -- Parse "exer" field
            local exer_match = str:match('"exer"%s*:%s*{(.-)}"?%s*}$')
            if exer_match then
              obj.exer = {}

              -- Parse acts array
              local acts_match = exer_match:match('"acts"%s*:%s*%[(.-)%]')
              if acts_match then
                obj.exer.acts = {}
                local act_pattern = '{([^}]*)}'
                for act_str in acts_match:gmatch(act_pattern) do
                  local act = {}
                  for key, value in act_str:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
                    act[key] = value
                  end
                  table.insert(obj.exer.acts, act)
                end
              end

              -- Parse apps array
              local apps_match = exer_match:match('"apps"%s*:%s*%[(.-)%]')
              if apps_match then
                obj.exer.apps = {}
                local app_pattern = '{([^}]*)}'
                for app_str in apps_match:gmatch(app_pattern) do
                  local app = {}
                  for key, value in app_str:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
                    app[key] = value
                  end
                  table.insert(obj.exer.apps, app)
                end
              end

              -- Parse compilers object
              local compilers_match = exer_match:match('"compilers"%s*:%s*{(.-)}"?')
              if compilers_match then
                obj.exer.compilers = {} -- This is a simplified parser, won't handle nested objects perfectly
                -- But good enough for basic testing
              end
            end

            -- Parse root-level acts
            local root_acts = str:match('"acts"%s*:%s*%[(.-)%]')
            if root_acts and not obj.exer then
              obj.acts = {}
              local act_pattern = '{([^}]*)}'
              for act_str in root_acts:gmatch(act_pattern) do
                local act = {}
                for key, value in act_str:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
                  act[key] = value
                end
                table.insert(obj.acts, act)
              end
            end

            return obj
          end

          return {}
        end)

        return ok and result or {}
      end,
      maparg = function(lhs, mode, abbr, dict) return '' end,
    },
    api = {
      nvim_buf_get_name = function(bufnr) return M.ctx.filepath end,
      nvim_command = function() end,
      nvim_set_current_dir = function(dir) end,
      nvim_set_keymap = function(mode, lhs, rhs, opts) end,
      nvim_get_option_value = function(opt, ctx)
        if opt == 'filetype' then return M.ctx.filetype end
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
    tbl_deep_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({ ... }) do
        for k, v in pairs(tbl) do
          if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = vim.tbl_deep_extend('force', result[k], v)
          else
            result[k] = v
          end
        end
      end
      return result
    end,
    tbl_extend = function(behavior, ...)
      local result = {}
      for i = 1, select('#', ...) do
        local t = select(i, ...)
        if t then
          for k, v in pairs(t) do
            result[k] = v
          end
        end
      end
      return result
    end,
  }

  -- 統一設定全域 vim 和 _G.vim
  vim = fake
  _G.vim = fake
  describe = M.describe
  it = M.it
  assert = M.assert

  return fake
end

function M.createTestFile(path, content)
  local dir = path:match('(.*)/[^/]*$')
  if dir then os.execute('mkdir -p ' .. dir) end
  local f = io.open(path, 'w')
  if f then
    f:write(content or '')
    f:close()
    return true
  end
  return false
end

local function inferFileType(path)
  local ext = path:match('%.([^%.]*)$')
  if not ext then return 'text' end

  local extMap = {
    py = 'python',
    c = 'c',
    cpp = 'cpp',
    js = 'javascript',
    ts = 'typescript',
    lua = 'lua',
    sh = 'sh',
    go = 'go',
    rs = 'rust',
    java = 'java',
    kt = 'kotlin',
    swift = 'swift',
    dart = 'dart',
  }

  return extMap[ext] or ext
end

function M.withTestFile(path, content, filetype, callback)
  if type(filetype) == 'function' then
    callback = filetype
    filetype = nil
  end

  M.createTestFile(path, content)
  local octx = {
    filepath = M.ctx.filepath,
    filetype = M.ctx.filetype,
  }

  M.ctx.filepath = path
  M.ctx.filetype = filetype or inferFileType(path)
  M.setup()

  local success, result = pcall(callback)

  M.ctx.filepath = octx.filepath
  M.ctx.filetype = octx.filetype
  M.setup()

  local dir = path:match('(.*)/[^/]*$')
  if dir and dir ~= '.' then
    os.execute('rm -rf ' .. dir)
  else
    os.execute('rm -f ' .. path)
  end

  if not success then error(result) end
  return result
end

function M.testCtx(filepath, filetype)
  M.ctx.filepath = filepath
  M.ctx.filetype = filetype
  -- Force reload the fake vim to pick up new context
  M.setup()
end

return M
