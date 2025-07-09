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
      local text = (opt.text or ''):lower():gsub('%s+', '')
      local typeStr = (opt.type or ''):lower():gsub('%s+', '')
      local nameStr = (opt.name or ''):lower():gsub('%s+', '')
      local descStr = (opt.desc or ''):lower():gsub('%s+', '')
      local qlow = ste.query:lower():gsub('%s+', '')
      local itemNum = tostring(displayNum)

      if qlow == '' then
        local optCopy = vim.tbl_deep_extend('force', opt, {})
        optCopy.originalNum = displayNum
        table.insert(ste.filteredOpts, optCopy)
      else
        local emTxt = text:find(qlow, 1, true)
        local exTyp = typeStr:find(qlow, 1, true)
        local emNam = nameStr:find(qlow, 1, true)
        local emDsc = descStr:find(qlow, 1, true)
        local fmTxt, fmsTxt = fuzzyMatch(text, qlow)
        local fmTyp, fmsTyp = fuzzyMatch(typeStr, qlow)
        local fmNam, fmsNam = fuzzyMatch(nameStr, qlow)
        local fmDsc, fmsDsc = fuzzyMatch(descStr, qlow)
        local numMatch = itemNum:find(qlow, 1, true)

        local hasExactMatch = emTxt or exTyp or emNam or emDsc
        local hasFuzzyMatch = fmTxt or fmTyp or fmNam or fmDsc

        if hasExactMatch or hasFuzzyMatch or numMatch then
          local filteredOpt = vim.tbl_deep_extend('force', opt, {})
          filteredOpt.originalNum = displayNum

          if hasExactMatch then
            filteredOpt.matchType = 'exact'
            if emTxt then
              filteredOpt.matchField = 'text'
              filteredOpt.matchStart = emTxt
              filteredOpt.matchEnd = emTxt + #qlow - 1
            elseif exTyp then
              filteredOpt.matchField = 'type'
              filteredOpt.matchStart = exTyp + 1
              filteredOpt.matchEnd = exTyp + #qlow - 0
            elseif emNam then
              filteredOpt.matchField = 'name'
              filteredOpt.matchStart = emNam + 1
              filteredOpt.matchEnd = emNam + #qlow - 0
            elseif emDsc then
              filteredOpt.matchField = 'desc'
              filteredOpt.matchStart = emDsc + 1
              filteredOpt.matchEnd = emDsc + #qlow - 0
            end
          elseif hasFuzzyMatch then
            filteredOpt.matchType = 'fuzzy'
            if fmTxt then
              filteredOpt.matchField = 'text'
              filteredOpt.matchPositions = fmsTxt
            elseif fmTyp then
              filteredOpt.matchField = 'type'
              filteredOpt.matchPositions = fmsTyp
            elseif fmNam then
              filteredOpt.matchField = 'name'
              filteredOpt.matchPositions = fmsNam
            elseif fmDsc then
              filteredOpt.matchField = 'desc'
              filteredOpt.matchPositions = fmsDsc
            end
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
