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

local function splitKeywords(query)
  local keywords = {}
  for word in query:gmatch('%S+') do
    if word ~= '' then table.insert(keywords, word:lower()) end
  end
  return keywords
end

local function crossFieldMatch(opt, keywords)
  if #keywords == 0 then return false, 0, {} end

  local text = (opt.text or ''):lower()
  local typeStr = (opt.type or ''):lower()
  local nameStr = (opt.name or ''):lower()
  local descStr = (opt.desc or ''):lower()

  local combined = typeStr .. ' ' .. text .. ' ' .. nameStr .. ' ' .. descStr
  local score = 0
  local matchInfo = { fields = {}, type = 'cross_field' }

  for _, keyword in ipairs(keywords) do
    local keywordMatched = false

    local exactPos = combined:find(keyword, 1, true)
    if exactPos then
      keywordMatched = true
      score = score + 100
      if combined:find('%f[%w]' .. vim.pesc(keyword) .. '%f[%W]') then score = score + 50 end
    else
      local fuzzyMatched, positions = fuzzyMatch(combined, keyword)
      if fuzzyMatched then
        keywordMatched = true
        score = score + 10
      end
    end

    if not keywordMatched then return false, 0, {} end
  end

  local continuousBonus = 0
  local fullQuery = table.concat(keywords, ' ')
  if combined:find(fullQuery, 1, true) then continuousBonus = #keywords * 200 end

  score = score + continuousBonus

  return true, score, matchInfo
end

function M.filterOpts()
  local ste = state.ste
  local candidateOpts = {}

  local displayNum = 0
  for idx, opt in ipairs(ste.opts) do
    if opt.value == 'separator' then
      -- Only include separator when no search query
      if ste.query == '' then table.insert(candidateOpts, { opt = opt, score = 0 }) end
    else
      displayNum = displayNum + 1
      local optCopy = vim.tbl_deep_extend('force', opt, {})
      optCopy.originalNum = displayNum

      if ste.query == '' then
        table.insert(candidateOpts, { opt = optCopy, score = 0 })
      else
        local matched = false
        local totalScore = 0

        -- Try cross-field matching first (for space-separated queries)
        local keywords = splitKeywords(ste.query)
        if #keywords > 1 then
          local crossMatched, crossScore, crossInfo = crossFieldMatch(opt, keywords)
          if crossMatched then
            matched = true
            totalScore = crossScore
            optCopy.matchType = 'cross_field'
            optCopy.matchInfo = crossInfo
          end
        end

        -- Fallback to original single-field matching
        if not matched then
          local text = (opt.text or ''):lower():gsub('%s+', '')
          local typeStr = (opt.type or ''):lower():gsub('%s+', '')
          local nameStr = (opt.name or ''):lower():gsub('%s+', '')
          local descStr = (opt.desc or ''):lower():gsub('%s+', '')
          local qlow = ste.query:lower():gsub('%s+', '')
          local itemNum = tostring(displayNum)

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
            matched = true

            if hasExactMatch then
              totalScore = 1000
              optCopy.matchType = 'exact'
              if emTxt then
                optCopy.matchField = 'text'
                optCopy.matchStart = emTxt
                optCopy.matchEnd = emTxt + #qlow - 1
              elseif exTyp then
                optCopy.matchField = 'type'
                optCopy.matchStart = exTyp + 1
                optCopy.matchEnd = exTyp + #qlow - 0
              elseif emNam then
                optCopy.matchField = 'name'
                optCopy.matchStart = emNam + 1
                optCopy.matchEnd = emNam + #qlow - 0
              elseif emDsc then
                optCopy.matchField = 'desc'
                optCopy.matchStart = emDsc + 1
                optCopy.matchEnd = emDsc + #qlow - 0
              end
            elseif hasFuzzyMatch then
              totalScore = 500
              optCopy.matchType = 'fuzzy'
              if fmTxt then
                optCopy.matchField = 'text'
                optCopy.matchPositions = fmsTxt
              elseif fmTyp then
                optCopy.matchField = 'type'
                optCopy.matchPositions = fmsTyp
              elseif fmNam then
                optCopy.matchField = 'name'
                optCopy.matchPositions = fmsNam
              elseif fmDsc then
                optCopy.matchField = 'desc'
                optCopy.matchPositions = fmsDsc
              end
            elseif numMatch then
              totalScore = 800
              optCopy.matchType = 'number'
            end
          end
        end

        if matched then table.insert(candidateOpts, { opt = optCopy, score = totalScore }) end
      end
    end
  end

  -- Sort by score (highest first)
  table.sort(candidateOpts, function(a, b) return a.score > b.score end)

  -- Extract sorted options
  ste.filteredOpts = {}
  for _, candidate in ipairs(candidateOpts) do
    table.insert(ste.filteredOpts, candidate.opt)
  end

  if ste.selectedIdx > #ste.filteredOpts then ste.selectedIdx = math.max(1, #ste.filteredOpts) end

  ste.scrollOffset = 0
end

return M
