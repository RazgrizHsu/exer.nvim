local M = {}
local co = require('exer.core')
local ansi = require('exer.ui.ansi')
local windows = require('exer.ui.windows')

local function fmtSte(ste)
  local icons = {
    pending = '⏸',
    running = '▶',
    completed = '✓',
    failed = '✗',
  }
  local colors = {
    pending = 'Comment',
    running = 'Function',
    completed = 'String',
    failed = 'Error',
  }
  return icons[ste] or '?', colors[ste] or 'Normal'
end

local function getNowMs() return os.time() * 1000 + math.floor((vim.uv.hrtime() % 1e9) / 1e6) end

local function fmtDur(timeS, timeE)
  if not timeS then return '' end
  local ms = (timeE or getNowMs()) - timeS
  if ms < 0 then ms = 0 end
  local s = ms / 1000

  if s < 60 then
    return string.format('%.3fs', s)
  elseif s < 3600 then
    local mins = math.floor(s / 60)
    local secs = s % 60
    return string.format('%dm%.3fs', mins, secs)
  else
    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60
    return string.format('%dh%dm%.3fs', hours, mins, secs)
  end
end

local function fmtTime(tsMs)
  if not tsMs then return '' end
  local tsS = tsMs / 1000
  local ms = math.floor((tsS % 1) * 1000)
  return os.date('%Y-%m-%d %H:%M:%S', math.floor(tsS)) .. string.format('.%03d', ms)
end

function M.renderList()
  local listB = windows.listB
  local listW = windows.listW

  if not listB or not vim.api.nvim_buf_is_valid(listB) then return end

  local tks = co.tsk.getAll()
  local lines = {}
  local hls = {}

  if listW and vim.api.nvim_win_is_valid(listW) then
    local title = string.format('─TaskList─(%d)─run[%d]', #tks, co.tsk.cntRunning())
    vim.api.nvim_win_set_config(listW, { title = title })
  end

  for i, t in ipairs(tks) do
    local icon, color = fmtSte(t.status)
    local duration = fmtDur(t.startTime, t.endTime)
    local line = string.format(' %s %s %s', icon, t.name, duration)
    table.insert(lines, line)
    table.insert(hls, { line = i, col = 0, len = 1, group = color })
  end

  if #tks == 0 then
    table.insert(lines, '')
    table.insert(lines, 'No tasks yet')
    table.insert(lines, '')
  else
    table.insert(lines, '')
  end

  vim.bo[listB].modifiable = true
  vim.api.nvim_buf_set_lines(listB, 0, -1, false, lines)
  vim.bo[listB].modifiable = false

  for _, hl in ipairs(hls) do
    local nsId = vim.api.nvim_create_namespace('exer_ui_list')
    local colE = hl.len == -1 and -1 or (hl.col + hl.len)
    if hl.line < #lines then
      local txtLn = lines[hl.line + 1] or ''
      if colE > 0 and colE <= #txtLn then vim.api.nvim_buf_set_extmark(listB, nsId, hl.line, hl.col, {
        end_col = colE,
        hl_group = hl.group,
      }) end
    end
  end
end

function M.renderPanel(tid, autoScroll)
  local palB = windows.palB
  local palW = windows.palW
  if not palB or not vim.api.nvim_buf_is_valid(palB) then return end

  local t = co.tsk.get(tid)
  if not t then return end

  if palW and vim.api.nvim_win_is_valid(palW) then
    local title = string.format('─TaskPanel #%d - %s', t.id, t.name or 'Unknown')
    vim.api.nvim_win_set_config(palW, { title = title })
  end

  local lines = {}
  local hlAll = {}

  local icon = fmtSte(t.status)
  table.insert(lines, string.format('%s─Task #%d: %s', icon, t.id, t.name))
  table.insert(lines, '─────────────────────────────────────────')
  table.insert(lines, 'Command: ' .. t.cmd)
  table.insert(lines, 'Status: ' .. t.status)
  if t.startTime then table.insert(lines, 'StartTime: ' .. fmtTime(t.startTime)) end
  if t.endTime then table.insert(lines, 'EndTime: ' .. fmtTime(t.endTime)) end
  if t.startTime then table.insert(lines, 'Duration: ' .. fmtDur(t.startTime, t.endTime)) end
  if t.exitCode then table.insert(lines, 'ExitCode: ' .. t.exitCode) end
  table.insert(lines, '')
  table.insert(lines, 'Output:')
  table.insert(lines, '─────────────────────────────────────────')

  local lnHdr = #lines

  for i, line in ipairs(t.output) do
    local lineClean, highlights = ansi.parse(line, lnHdr + i)
    table.insert(lines, lineClean)

    for _, hl in ipairs(highlights) do
      table.insert(hlAll, hl)
    end
  end

  vim.bo[palB].modifiable = true
  vim.api.nvim_buf_set_lines(palB, 0, -1, false, lines)
  vim.bo[palB].modifiable = false

  ansi.apply(palB, hlAll)

  if autoScroll then
    if palW and vim.api.nvim_win_is_valid(palW) then vim.api.nvim_win_set_cursor(palW, { #lines, 0 }) end
  end
end

function M.renderPlaceholder(msg)
  local palW = windows.palW

  if not palW or not vim.api.nvim_win_is_valid(palW) then return end

  local placeholderB = vim.api.nvim_create_buf(false, true)
  vim.bo[placeholderB].buftype = 'nofile'
  vim.bo[placeholderB].bufhidden = 'wipe'
  vim.bo[placeholderB].modifiable = true
  vim.api.nvim_buf_set_name(placeholderB, 'TaskPanel - Placeholder')

  local lines = {
    'TaskPanel',
    '─────────────────────────────────────────',
    '',
    msg or 'Select a task from the list to view panel',
    '',
    'Keys:',
    '  <Enter> - View task panel',
    '  s - Stop task',
    '  c - Clear completed tasks',
    '  q - Close UI',
  }

  vim.api.nvim_buf_set_lines(placeholderB, 0, -1, false, lines)
  vim.bo[placeholderB].modifiable = false

  local syntax = require('exer.ui.syntax')
  syntax.apply(placeholderB)

  vim.api.nvim_win_set_buf(palW, placeholderB)

  return placeholderB
end

function M.getSelectedTask()
  local listW = windows.listW
  if not listW or not vim.api.nvim_win_is_valid(listW) then return nil end

  local cursor = vim.api.nvim_win_get_cursor(listW)
  local line = cursor[1]
  if line < 1 then return nil end

  local tasks = co.tsk.getAll()
  if line <= #tasks then return tasks[line] end
  return nil
end

return M
