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
    assert.is_true(fuzzyMatch('build', 'build'))
    assert.is_true(fuzzyMatch('test', 'test'))
  end)

  it('matches fuzzy patterns', function()
    -- Test case that the user mentioned
    assert.is_true(fuzzyMatch('jest:testatcursor', 'testcur'))

    -- Other fuzzy patterns
    assert.is_true(fuzzyMatch('jest:testatcursor', 'jtc'))
    assert.is_true(fuzzyMatch('buildproject', 'bldprj'))
    assert.is_true(fuzzyMatch('typescript:compile', 'tscomp'))
  end)

  it('rejects non-matching patterns', function()
    assert.is_false(fuzzyMatch('build', 'xyz'))
    assert.is_false(fuzzyMatch('test', 'abc'))
    assert.is_false(fuzzyMatch('jest:testatcursor', 'xyz'))
  end)

  it('handles empty query', function()
    assert.is_true(fuzzyMatch('anything', ''))
    assert.is_true(fuzzyMatch('', ''))
  end)

  it('handles edge cases', function()
    assert.is_false(fuzzyMatch('', 'a'))
    assert.is_true(fuzzyMatch('a', 'a'))
    assert.is_false(fuzzyMatch('a', 'ab'))
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
    assert.are.equal('jest:testatcursor', textProcessed)
    assert.are.equal('testcur', queryProcessed)

    -- Exact match fails
    local exactMatch = textProcessed:find(queryProcessed, 1, true)
    assert.is_nil(exactMatch)

    -- But fuzzy match succeeds
    assert.is_true(fuzzyMatch(textProcessed, queryProcessed))
  end)
end)
