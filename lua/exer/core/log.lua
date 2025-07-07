--- Logger system for debugging and logging

local M = {}

M.enabled = true
M.logToFile = false
M.logFile = (vim.fn and vim.fn.stdpath and vim.fn.stdpath('cache') .. '/exer.log') or '/tmp/exer.log'

M.lv = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

M.lvNow = M.lv.INFO

function M.log(lv, msg, title)
  if not M.enabled then return end

  -- If it's a DEBUG message, only show when debug mode is enabled
  if lv == M.lv.DEBUG and not _G.g_exer_debug then return end

  -- For non-debug messages, use normal level filtering
  if lv ~= M.lv.DEBUG and lv < M.lvNow then return end

  local levelNames = { 'DEBUG', 'INFO', 'WARN', 'ERROR' }
  local levelName = levelNames[lv] or 'UNKNOWN'
  local fullTitle = (title and (title .. ' [' .. levelName .. ']')) or levelName

  local logMsg = string.format('[%s] %s: %s', os.date('%H:%M:%S'), fullTitle, msg)

  -- Output to Neovim notification
  if vim.notify then require('exer.core.utils').msg(msg, vim.log.levels.INFO) end

  -- Also output to file if enabled
  if M.logToFile then
    local file = io.open(M.logFile, 'a')
    if file then
      file:write(logMsg .. '\n')
      file:close()
    end
  end
end

function M.debug(msg, title) M.log(M.lv.DEBUG, msg, title) end

function M.info(msg, title) M.log(M.lv.INFO, msg, title) end

function M.warn(msg, title) M.log(M.lv.WARN, msg, title) end

function M.error(msg, title) M.log(M.lv.ERROR, msg, title) end

function M.setDebug(enabled)
  M.enabled = enabled
  require('exer.core.utils').msg('Debug logging: ' .. enabled, vim.log.levels.INFO)
end

return M
