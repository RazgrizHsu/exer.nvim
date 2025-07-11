local ut = require('tests.unitester')
ut.setup()

-- Direct test of the fuzzy matching logic
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

describe('Fuzzy matching algorithm', function()
  it('matches exact strings', function()
    ut.assert.is_true(fuzzyMatch('build', 'build'))
    ut.assert.is_true(fuzzyMatch('test', 'test'))
  end)

  it('matches fuzzy patterns', function()
    -- Test case that the user mentioned
    ut.assert.is_true(fuzzyMatch('jest:testatcursor', 'testcur'))

    -- Other fuzzy patterns
    ut.assert.is_true(fuzzyMatch('jest:testatcursor', 'jtc'))
    ut.assert.is_true(fuzzyMatch('buildproject', 'bldprj'))
    ut.assert.is_true(fuzzyMatch('typescript:compile', 'tscomp'))
  end)

  it('rejects non-matching patterns', function()
    ut.assert.is_false(fuzzyMatch('build', 'xyz'))
    ut.assert.is_false(fuzzyMatch('test', 'abc'))
    ut.assert.is_false(fuzzyMatch('jest:testatcursor', 'xyz'))
  end)

  it('handles empty query', function()
    ut.assert.is_true(fuzzyMatch('anything', ''))
    ut.assert.is_true(fuzzyMatch('', ''))
  end)

  it('handles edge cases', function()
    ut.assert.is_false(fuzzyMatch('', 'a'))
    ut.assert.is_true(fuzzyMatch('a', 'a'))
    ut.assert.is_false(fuzzyMatch('a', 'ab'))
  end)
end)

describe('Integration with filter logic', function()
  it('demonstrates the search problem and solution', function()
    local text = 'Jest: Test at Cursor'
    local query = 'testcur'

    -- Simulate the filter processing
    local textProcessed = text:lower():gsub('%s+', '')
    local queryProcessed = query:lower():gsub('%s+', '')

    -- Show the transformation
    ut.assert.are.equal('jest:testatcursor', textProcessed)
    ut.assert.are.equal('testcur', queryProcessed)

    -- Exact match fails
    local exactMatch = textProcessed:find(queryProcessed, 1, true)
    ut.assert.is_nil(exactMatch)

    -- But fuzzy match succeeds
    ut.assert.is_true(fuzzyMatch(textProcessed, queryProcessed))
  end)
end)

describe('Cross-field search functionality', function()
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

  it('matches across fields with space-separated keywords', function()
    local opt = {
      type = 'Cargo',
      text = 'Build Project',
      name = 'cargo',
      desc = 'Build Rust project',
    }

    local keywords = splitKeywords('car p')
    ut.assert.are.equal(2, #keywords)
    ut.assert.are.equal('car', keywords[1])
    ut.assert.are.equal('p', keywords[2])

    local matched, score, info = crossFieldMatch(opt, keywords)
    ut.assert.is_true(matched)
    ut.assert.is_true(score > 0)
  end)

  it('gives higher score for continuous matches', function()
    local opt = {
      type = 'Cargo',
      text = 'Build Project',
      name = 'cargo',
      desc = 'Build Rust project',
    }

    -- Test continuous match 'cargo build'
    local keywords1 = splitKeywords('cargo build')
    local matched1, score1, _ = crossFieldMatch(opt, keywords1)

    -- Test separated match 'car bui'
    local keywords2 = splitKeywords('car bui')
    local matched2, score2, _ = crossFieldMatch(opt, keywords2)

    ut.assert.is_true(matched1)
    ut.assert.is_true(matched2)
    ut.assert.is_true(score1 > score2) -- Continuous should score higher
  end)

  it('requires all keywords to match', function()
    local opt = {
      type = 'Cargo',
      text = 'Build Project',
      name = 'cargo',
      desc = 'Build Rust project',
    }

    -- Test with non-matching keyword
    local keywords = splitKeywords('car xyz')
    local matched, score, _ = crossFieldMatch(opt, keywords)

    ut.assert.is_false(matched)
    ut.assert.are.equal(0, score)
  end)

  it('handles single keyword gracefully', function()
    local opt = {
      type = 'Cargo',
      text = 'Build Project',
      name = 'cargo',
      desc = 'Build Rust project',
    }

    local keywords = splitKeywords('cargo')
    local matched, score, _ = crossFieldMatch(opt, keywords)

    ut.assert.is_true(matched)
    ut.assert.is_true(score > 0)
  end)

  it('handles empty fields gracefully', function()
    local opt = {
      type = 'Jest',
      text = 'Test at Cursor',
    }

    local keywords = splitKeywords('jest test')
    local matched, score, _ = crossFieldMatch(opt, keywords)

    ut.assert.is_true(matched)
    ut.assert.is_true(score > 0)
  end)
end)
