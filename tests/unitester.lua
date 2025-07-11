local M = {}

M.stats = { passed = 0, failed = 0, total = 0 }
M.ctx = { filepath = './tmp/test.py', filetype = 'py' }
M.current_describe = nil

function M.describe(name, func)
  M.current_describe = name

  if _G.ut_name_filter then
    local has_match = false
    if string.find(name:lower(), _G.ut_name_filter:lower()) then
      has_match = true
    else
      local temp_func = function()
        local orig_it = M.it
        M.it = function(it_name, it_func)
          if string.find(it_name:lower(), _G.ut_name_filter:lower()) then has_match = true end
        end
        func()
        M.it = orig_it
      end
      temp_func()
    end

    if not has_match then return end
  end

  if not utmode then
    print('\n📋 ' .. name)
    print(string.rep('-', 50))
  end
  func()
end

function M.it(name, func)
  if _G.ut_name_filter then
    local desc_match = M.current_describe and string.find(M.current_describe:lower(), _G.ut_name_filter:lower())
    local it_match = string.find(name:lower(), _G.ut_name_filter:lower())

    if not desc_match and not it_match then return end
  end

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

  -- Force reload of proj modules to use new vim instance
  -- package.loaded['exer.proj.vars'] = nil
  -- package.loaded['exer.proj'] = nil

  -- 使用真實的 nvim 環境，只需要補充測試特定的功能
  -- 不要覆蓋全局 assert，只設置測試助手函數
  describe = M.describe
  it = M.it

  -- 保持測試上下文設定
  local originals = {
    buf_get_name = vim.api.nvim_buf_get_name,
    get_option_value = vim.api.nvim_get_option_value,
  }

  -- 重寫部分 API 以支援測試上下文
  vim.api.nvim_buf_get_name = function(bufnr) return M.ctx.filepath end

  vim.api.nvim_get_option_value = function(opt, ctx)
    if opt == 'filetype' then return M.ctx.filetype end
    return originals.get_option_value(opt, ctx)
  end

  -- 需要一些額外的 vim 函數用於測試
  if not vim.fn.json_decode then vim.fn.json_decode = vim.json.decode end

  return vim
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

  -- 使用絕對路徑，確保與真實的 nvim 環境一致
  local abs_path = vim.fn.fnamemodify(path, ':p')
  M.ctx.filepath = abs_path
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

function M.itEnv(name, env, callback)
  M.it(name, function()
    local co = require('exer.core')
    local proj = require('exer.proj')
    local config = require('exer.config')
    local originalGetRoot = co.io.getRoot
    local originalFileExists = co.io.fileExists
    local originalReadFile = vim.fn.readfile
    local originalGetcwd = vim.fn.getcwd
    local originalExpand = vim.fn.expand

    -- 確保清理任何快取狀態
    proj.clearCache()

    -- 重置 config 狀態 - 強制重載預設值
    package.loaded['exer.config'] = nil
    config = require('exer.config')

    -- 設定 config 如果提供
    if env.config then config.setup(env.config) end

    -- Mock io.getRoot 而非改變工作目錄
    if env.cwd then co.io.getRoot = function() return env.cwd end end

    -- 建構內部檔案表，包含 files 和 mockFiles
    local internalFiles = {}
    if env.files then
      for filePath, content in pairs(env.files) do
        local fullPath = env.cwd and (env.cwd .. '/' .. filePath) or filePath
        internalFiles[fullPath] = content
      end
    end
    if env.mockFiles then
      for filePath, content in pairs(env.mockFiles) do
        internalFiles[filePath] = content
      end
    end

    -- Mock fileExists 檢查內部表和實體檔案
    if next(internalFiles) then
      co.io.fileExists = function(path)
        -- 先檢查內部表
        if internalFiles[path] ~= nil then return true end
        -- 找不到則檢查實體檔案
        return originalFileExists(path)
      end
    end

    -- Mock readfile 檢查內部表和實體檔案
    if next(internalFiles) then
      vim.fn.readfile = function(path)
        -- 先檢查內部表
        local content = internalFiles[path]
        if content then
          if type(content) == 'string' then
            return vim.split(content, '\n')
          elseif type(content) == 'table' then
            return content
          end
        end
        -- 找不到則使用原始 readfile
        return originalReadFile(path)
      end
    end

    -- 設置測試上下文
    local octx = {
      filepath = M.ctx.filepath,
      filetype = M.ctx.filetype,
    }

    -- 如果 env 指定了 currentFile，自動設定測試上下文
    if env.currentFile then
      local fullPath = env.cwd and (env.cwd .. '/' .. env.currentFile) or env.currentFile
      M.ctx.filepath = fullPath
      M.ctx.filetype = env.filetype or inferFileType(env.currentFile)
    end

    -- Mock vim functions for variable expansion
    if env.cwd then vim.fn.getcwd = function() return env.cwd end end

    if env.currentFile then
      local fullPath = env.cwd and (env.cwd .. '/' .. env.currentFile) or env.currentFile
      local fileName = env.currentFile:match('[^/]+$')
      local nameWithoutExt = fileName:match('(.+)%..+$') or fileName
      local ext = fileName:match('%.([^%.]+)$') or ''

      vim.fn.expand = function(pattern)
        -- Mock expand patterns for file variables
        if pattern == '%:p' then
          return fullPath
        elseif pattern == '%:p:h' then
          return env.cwd
        elseif pattern == '%:t' then
          return fileName
        elseif pattern == '%:t:r' then
          return nameWithoutExt
        elseif pattern == '%:p:r' then
          return env.cwd .. '/' .. nameWithoutExt
        elseif pattern == '%:e' then
          return ext
        else
          return originalExpand(pattern)
        end
      end
    end

    -- Note: vim.v.servername is read-only, so we can't mock it in tests

    -- 執行測試
    local success, result = pcall(callback)

    -- 無論是否成功，都要清理資源
    -- 恢復上下文
    M.ctx.filepath = octx.filepath
    M.ctx.filetype = octx.filetype

    -- 恢復原始函數
    co.io.getRoot = originalGetRoot
    co.io.fileExists = originalFileExists
    vim.fn.readfile = originalReadFile
    vim.fn.getcwd = originalGetcwd
    vim.fn.expand = originalExpand

    -- 不需要清理實體檔案，因為我們用 mock

    -- 最後清理快取
    proj.clearCache()

    -- 重置 config 狀態
    package.loaded['exer.config'] = nil

    if not success then error(result) end
    return result
  end)
end

return M
