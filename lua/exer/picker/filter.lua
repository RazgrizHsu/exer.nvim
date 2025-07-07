local M = {}

local state = require('exer.picker.state')

local function fuzzyMatch(text, query)
  if query == '' then return true end

  local tIdx = 1
  local qIdx = 1
  local tLen = #text
  local qLen = #query

  while tIdx <= tLen and qIdx <= qLen do
    if text:sub(tIdx, tIdx) == query:sub(qIdx, qIdx) then qIdx = qIdx + 1 end
    tIdx = tIdx + 1
  end

  return qIdx > qLen
end

function M.filterOpts()
  local ste = state.ste
  ste.filteredOpts = {}

  for _, opt in ipairs(ste.opts) do
    if opt.value == 'separator' then
      -- Only include separator when no search query
      if ste.query == '' then table.insert(ste.filteredOpts, opt) end
    else
      local text = (opt.text):lower():gsub('%s+', '')
      local queryLower = ste.query:lower():gsub('%s+', '')

      if queryLower == '' or text:find(queryLower, 1, true) or fuzzyMatch(text, queryLower) then table.insert(ste.filteredOpts, opt) end
    end
  end

  if ste.selectedIdx > #ste.filteredOpts then ste.selectedIdx = math.max(1, #ste.filteredOpts) end

  ste.scrollOffset = 0
end

return M
