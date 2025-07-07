local M = {}

local state = require('exer.picker.state')

local function fuzzyMatch(text, query)
  if query == '' then return true, {} end

  local tIdx = 1
  local qIdx = 1
  local tLen = #text
  local qLen = #query
  local matches = {}

  while tIdx <= tLen and qIdx <= qLen do
    if text:sub(tIdx, tIdx) == query:sub(qIdx, qIdx) then
      table.insert(matches, tIdx)
      qIdx = qIdx + 1
    end
    tIdx = tIdx + 1
  end

  return qIdx > qLen, matches
end

function M.filterOpts()
  local ste = state.ste
  ste.filteredOpts = {}

  local displayNum = 0
  for idx, opt in ipairs(ste.opts) do
    if opt.value == 'separator' then
      -- Only include separator when no search query
      if ste.query == '' then table.insert(ste.filteredOpts, opt) end
    else
      displayNum = displayNum + 1
      local text = (opt.text):lower():gsub('%s+', '')
      local queryLower = ste.query:lower():gsub('%s+', '')
      local itemNum = tostring(displayNum)

      if queryLower == '' then
        local optCopy = vim.tbl_deep_extend('force', opt, {})
        optCopy.originalNum = displayNum
        table.insert(ste.filteredOpts, optCopy)
      else
        local exactMatch = text:find(queryLower, 1, true)
        local fuzzyMatched, fuzzyMatches = fuzzyMatch(text, queryLower)
        local numMatch = itemNum:find(queryLower, 1, true)

        if exactMatch or fuzzyMatched or numMatch then
          local filteredOpt = vim.tbl_deep_extend('force', opt, {})
          filteredOpt.originalNum = displayNum
          if exactMatch then
            filteredOpt.matchType = 'exact'
            filteredOpt.matchStart = exactMatch
            filteredOpt.matchEnd = exactMatch + #queryLower - 1
          elseif fuzzyMatched then
            filteredOpt.matchType = 'fuzzy'
            filteredOpt.matchPositions = fuzzyMatches
          elseif numMatch then
            filteredOpt.matchType = 'number'
          end
          table.insert(ste.filteredOpts, filteredOpt)
        end
      end
    end
  end

  if ste.selectedIdx > #ste.filteredOpts then ste.selectedIdx = math.max(1, #ste.filteredOpts) end

  ste.scrollOffset = 0
end

return M
