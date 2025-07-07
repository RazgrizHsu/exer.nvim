local M = {}

local state = require('exer.picker.state')

local function renderList()
  if not state.isListBufValid() then return end

  local ste = state.ste
  local lines = {}
  local maxVisible = 15

  local validCount = 0
  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value ~= 'separator' then validCount = validCount + 1 end
  end

  if validCount > maxVisible then
    if ste.selectedIdx <= ste.scrollOffset then
      ste.scrollOffset = math.max(0, ste.selectedIdx - 1)
    elseif ste.selectedIdx > ste.scrollOffset + maxVisible - 2 then
      ste.scrollOffset = math.min(validCount - maxVisible + 1, ste.selectedIdx - maxVisible + 2)
    end
  end

  local currentLine = 0
  local currentValidIdx = 0
  local visibleLines = 0
  local lineToOptMap = {}

  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value == 'separator' then
      currentLine = currentLine + 1
      if currentLine > ste.scrollOffset and visibleLines < maxVisible then
        -- Generate separator line dynamically based on window width
        local winWidth = 69 -- Default width, can be made dynamic
        if state.isListWinValid() then winWidth = vim.api.nvim_win_get_width(ste.listWin) end
        local separatorWidth = math.max(1, winWidth + 1)
        local dashCount = math.floor(separatorWidth / 2)
        local separatorLine = string.rep('- ', dashCount):sub(1, separatorWidth)
        table.insert(lines, separatorLine)
        visibleLines = visibleLines + 1
      end
    else
      currentValidIdx = currentValidIdx + 1
      currentLine = currentLine + 1

      if currentLine > ste.scrollOffset and visibleLines < maxVisible then
        local typeStr = opt.type or ''
        local textStr = opt.text or ''
        local descStr = opt.desc and (' - ' .. opt.desc) or ''
        local displayNum = opt.originalNum or currentValidIdx
        local line = string.format('%3d %-6s %-20s%s', displayNum, typeStr, textStr, descStr)

        if currentValidIdx == ste.selectedIdx then
          line = '►' .. line:sub(2)
        else
          line = ' ' .. line:sub(2)
        end

        table.insert(lines, line)
        lineToOptMap[#lines] = opt
        visibleLines = visibleLines + 1
      end
    end
  end

  vim.bo[ste.listBuf].modifiable = true
  vim.api.nvim_buf_set_lines(ste.listBuf, 0, -1, false, lines)
  vim.bo[ste.listBuf].modifiable = false

  local nsId = vim.api.nvim_create_namespace('raz_picker_list')
  vim.api.nvim_buf_clear_namespace(ste.listBuf, nsId, 0, -1)

  local syntaxNs = vim.api.nvim_create_namespace('raz_picker_syntax')
  vim.api.nvim_buf_clear_namespace(ste.listBuf, syntaxNs, 0, -1)

  local matchNs = vim.api.nvim_create_namespace('raz_picker_matches')
  vim.api.nvim_buf_clear_namespace(ste.listBuf, matchNs, 0, -1)

  for i, line in ipairs(lines) do
    local lineIdx = i - 1

    -- Handle separator lines (dynamically generated dashed lines)
    if line:match('^%- ') and line:match('^[%- ]+$') then
      vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, 0, {
        end_col = #line,
        hl_group = 'Comment',
      })
    elseif line ~= '' then
      local content = line
      if content:match('^► ') or content:match('^  ') then content = content:sub(3) end

      -- Parse: "  1 TS     build: hello_world  - Build hello world app"
      local numStart, numEnd = content:find('^%s*%d+')
      if numStart then
        local actualNumStart = #line - #content + numStart - 1
        -- Highlight number
        vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, actualNumStart, {
          end_col = actualNumStart + (numEnd - numStart + 1),
          hl_group = 'Number',
        })

        local afterNum = content:sub(numEnd + 1)
        -- Find type (after number and spaces)
        local typeStart, typeEnd = afterNum:find('^%s*(%S+)')
        if typeStart and typeEnd then
          local actualTypeStart = actualNumStart + (numEnd - numStart + 1) + typeStart - 1
          local actualTypeEnd = actualNumStart + (numEnd - numStart + 1) + typeEnd
          -- Highlight type
          vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, actualTypeStart, {
            end_col = actualTypeEnd,
            hl_group = 'Keyword',
          })

          -- Find description part (starts with " - ")
          local descPos = line:find(' %- ')
          if descPos then
            -- Text part (between type and description)
            vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, actualTypeEnd, {
              end_col = descPos,
              hl_group = 'Normal',
            })
            -- Description part (from " - " to end)
            vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, descPos, {
              end_col = #line,
              hl_group = 'Comment',
            })
          else
            -- No description, just highlight rest as normal
            vim.api.nvim_buf_set_extmark(ste.listBuf, syntaxNs, lineIdx, actualTypeEnd, {
              end_col = #line,
              hl_group = 'Normal',
            })
          end
        end
      end
    end
  end

  -- Add match highlighting
  for lineIdx, line in ipairs(lines) do
    local lineNumber = lineIdx - 1
    local opt = lineToOptMap[lineIdx]

    if opt and opt.matchType and ste.query ~= '' then
      local textStart = line:find(opt.text, 1, true)
      if textStart then
        local queryLower = ste.query:lower():gsub('%s+', '')
        local textLower = opt.text:lower():gsub('%s+', '')

        if opt.matchType == 'exact' then
          local matchStart = textStart + opt.matchStart - 1 - 1
          local matchEnd = textStart + opt.matchEnd - 1
          vim.api.nvim_buf_set_extmark(ste.listBuf, matchNs, lineNumber, matchStart, {
            end_col = matchEnd,
            hl_group = 'IncSearch',
          })
        elseif opt.matchType == 'fuzzy' and opt.matchPositions then
          for _, pos in ipairs(opt.matchPositions) do
            local actualPos = textStart + pos - 1 - 1
            vim.api.nvim_buf_set_extmark(ste.listBuf, matchNs, lineNumber, actualPos, {
              end_col = actualPos + 1,
              hl_group = 'Search',
            })
          end
        elseif opt.matchType == 'number' then
          local numStart = line:find('%d+')
          if numStart then
            local numEnd = line:find('%D', numStart) or #line + 1
            vim.api.nvim_buf_set_extmark(ste.listBuf, matchNs, lineNumber, numStart - 1, {
              end_col = numEnd - 1,
              hl_group = 'WarningMsg',
            })
          end
        end
      end
    end
  end

  currentLine = 0
  currentValidIdx = 0
  local renderedLine = 0

  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value == 'separator' then
      currentLine = currentLine + 1
      if currentLine > ste.scrollOffset and renderedLine < #lines then renderedLine = renderedLine + 1 end
    else
      currentValidIdx = currentValidIdx + 1
      currentLine = currentLine + 1

      if currentLine > ste.scrollOffset and renderedLine < #lines then
        renderedLine = renderedLine + 1

        if currentValidIdx == ste.selectedIdx then
          vim.api.nvim_buf_set_extmark(ste.listBuf, nsId, renderedLine - 1, 0, {
            end_row = renderedLine,
            end_col = 0,
            hl_group = 'Visual',
            hl_eol = true,
          })
          break
        end
      end
    end
  end
end

local function renderInput()
  if not state.isInputBufValid() then return end

  local ste = state.ste
  local optsValid = 0
  for _, opt in ipairs(ste.filteredOpts) do
    if opt.value ~= 'separator' then optsValid = optsValid + 1 end
  end

  local lineStatus = string.format('%d/%d', math.min(ste.selectedIdx, optsValid), optsValid)
  if optsValid > 15 then lineStatus = lineStatus .. string.format(' [%d-%d]', ste.scrollOffset + 1, math.min(ste.scrollOffset + 15, optsValid)) end
  local dispQuery = '> ' .. ste.query
  local padding = math.max(1, 66 - #dispQuery - #lineStatus)
  local lnInput = dispQuery .. string.rep(' ', padding) .. lineStatus

  vim.bo[ste.inputBuf].modifiable = true
  vim.api.nvim_buf_set_lines(ste.inputBuf, 0, -1, false, { lnInput })
  vim.bo[ste.inputBuf].modifiable = false

  if state.isInputWinValid() then
    local colCur = 2 + #ste.query
    vim.api.nvim_win_set_cursor(ste.inputWin, { 1, colCur })
  end
end

function M.renderPicker()
  renderList()
  renderInput()
end

return M
