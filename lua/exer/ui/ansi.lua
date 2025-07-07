local M = {}

function M.parse(line, lineNum)
  if not line then return line, {} end

  local highlights = {}
  local lineClean = ''
  local hlCur = nil
  local pos = 1

  -- simple ANSI color code pattern matching
  local patAnsi = '\027%[([%d;]*)m'

  while pos <= #line do
    local start, ended, codes = line:find(patAnsi, pos)

    if start then
      -- add text before ANSI sequence
      local txtBef = line:sub(pos, start - 1)
      if #txtBef > 0 then
        if hlCur then table.insert(highlights, {
          line = lineNum,
          col = #lineClean,
          len = #txtBef,
          hl_group = hlCur,
        }) end
        lineClean = lineClean .. txtBef
      end

      if codes and codes ~= '' then
        for code in codes:gmatch('(%d+)') do
          code = tonumber(code)
          if code == 0 then -- Reset
            hlCur = nil
          elseif code == 1 then -- Bold
            hlCur = 'Title'
          -- foreground colors (30-37, 90-97)
          elseif code == 31 or code == 91 then -- Red
            hlCur = 'ErrorMsg'
          elseif code == 32 or code == 92 then -- Green
            hlCur = 'String'
          elseif code == 33 or code == 93 then -- Yellow
            hlCur = 'WarningMsg'
          elseif code == 34 or code == 94 then -- Blue
            hlCur = 'Function'
          elseif code == 35 or code == 95 then -- Magenta
            hlCur = 'Special'
          elseif code == 36 or code == 96 then -- Cyan
            hlCur = 'Directory'
          -- background colors (40-47, 100-107)
          elseif code == 42 or code == 102 then -- Green bg
            hlCur = 'DiffAdd'
          elseif code == 41 or code == 101 then -- Red bg
            hlCur = 'DiffDelete'
          elseif code == 43 or code == 103 then -- Yellow bg
            hlCur = 'DiffChange'
          elseif code == 44 or code == 104 then -- Blue bg
            hlCur = 'PmenuSel'
          end
        end
      end

      pos = ended + 1
    else
      -- no more ANSI sequences, add remaining text
      local remaining = line:sub(pos)
      if #remaining > 0 then
        if hlCur then table.insert(highlights, {
          line = lineNum,
          col = #lineClean,
          len = #remaining,
          hl_group = hlCur,
        }) end
        lineClean = lineClean .. remaining
      end
      break
    end
  end

  return lineClean, highlights
end

function M.apply(buf, highlights)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local nsId = vim.api.nvim_create_namespace('raz_ansi_colors')
  vim.api.nvim_buf_clear_namespace(buf, nsId, 0, -1)

  for _, hl in ipairs(highlights) do
    if hl.hl_group and hl.line and hl.len and hl.len > 0 then
      -- ensure not exceeding buffer line count
      local line_count = vim.api.nvim_buf_line_count(buf)
      if hl.line < line_count then
        local lines = vim.api.nvim_buf_get_lines(buf, hl.line, hl.line + 1, false)
        if #lines > 0 then
          local txtLn = lines[1] or ''
          local colE = math.min(hl.col + hl.len, #txtLn)
          if colE > hl.col then
            vim.api.nvim_buf_set_extmark(buf, nsId, hl.line, hl.col, {
              end_col = colE,
              hl_group = hl.hl_group,
              priority = 200, -- high priority to override syntax highlighting
            })
          end
        end
      end
    end
  end
end

return M
