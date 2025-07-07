---@diagnostic disable: redefined-local
local M = {}

local function trim(s) return s:match('^%s*(.-)%s*$') end

-- parse value (handle quotes, booleans, numbers)
local function parseVar(val)
  val = trim(val)

  if val == 'true' then
    return true
  elseif val == 'false' then
    return false
  elseif val:match('^%d+$') then
    return tonumber(val)
  elseif val:match('^%d+%.%d+$') then
    return tonumber(val)
  elseif val:match('^".*"$') then
    return val:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
  elseif val:match("^'.*'$") then
    return val:sub(2, -2)
  else
    return val
  end
end

-- parse array string (like ["a", "b", "c"])
local function parseArrayStrs(txt)
  local itms = {}
  txt = trim(txt)

  if txt:match('^%[.*%]$') then txt = txt:sub(2, -2) end

  txt = trim(txt)
  if txt == '' then return {} end

  local cur = ''
  local inQuotes = false
  local quoteChar = nil

  for i = 1, #txt do
    local char = txt:sub(i, i)

    if not inQuotes then
      if char == '"' or char == "'" then
        inQuotes = true
        quoteChar = char
        cur = cur .. char
      elseif char == ',' then
        local itm = trim(cur)
        if itm ~= '' then itms[#itms + 1] = parseVar(itm) end
        cur = ''
      else
        cur = cur .. char
      end
    else
      cur = cur .. char
      if char == quoteChar then
        inQuotes = false
        quoteChar = nil
      end
    end
  end

  local itm = trim(cur)
  if itm ~= '' then itms[#itms + 1] = parseVar(itm) end

  return itms
end

-- parse inline table (like { key = "value", key2 = "value2" })
local function parseInlineTable(txt)
  local tbl = {}
  txt = trim(txt)

  if txt:match('^%{.*%}$') then txt = txt:sub(2, -2) end

  txt = trim(txt)
  if txt == '' then return {} end

  local pairsList = {}
  local curPair = ''
  local inQuotes = false
  local quoteChar = nil
  local braceCnt = 0

  for i = 1, #txt do
    local char = txt:sub(i, i)

    if not inQuotes then
      if char == '"' or char == "'" then
        inQuotes = true
        quoteChar = char
        curPair = curPair .. char
      elseif char == '{' then
        braceCnt = braceCnt + 1
        curPair = curPair .. char
      elseif char == '}' then
        braceCnt = braceCnt - 1
        curPair = curPair .. char
      elseif char == ',' and braceCnt == 0 then
        local pair = trim(curPair)
        if pair ~= '' then pairsList[#pairsList + 1] = pair end
        curPair = ''
      else
        curPair = curPair .. char
      end
    else
      curPair = curPair .. char
      if char == quoteChar then
        inQuotes = false
        quoteChar = nil
      end
    end
  end

  local trimmedPair = trim(curPair)
  if trimmedPair ~= '' then pairsList[#pairsList + 1] = trimmedPair end

  for _, pair in ipairs(pairsList) do
    local eqPos = pair:find('=')
    if eqPos then
      local key = trim(pair:sub(1, eqPos - 1))
      local val = trim(pair:sub(eqPos + 1))

      if key:match('^".*"$') or key:match("^'.*'$") then key = key:sub(2, -2) end

      tbl[key] = tostring(parseVar(val))
    end
  end

  return tbl
end

-- 通用的 TOML 陣列解析器
function M.parseArray(txt, nam)
  if not txt or txt == '' then return nil end

  local rst = {}
  rst[nam] = {}

  local pattern = nam .. '%s*=%s*%['
  local arrayStart = txt:find(pattern)
  if not arrayStart then return rst end

  local cnt = 0
  local posS = nil
  local posE = nil

  for i = arrayStart, #txt do
    local char = txt:sub(i, i)
    if char == '[' then
      if cnt == 0 then posS = i end
      cnt = cnt + 1
    elseif char == ']' then
      cnt = cnt - 1
      if cnt == 0 then
        posE = i
        break
      end
    end
  end

  if not posS or not posE then return rst end

  local arrayContent = txt:sub(posS + 1, posE - 1)

  local obs = {}
  local curObj = ''
  local cntBra = 0
  local inQuotes = false
  local quoteChar = nil

  for i = 1, #arrayContent do
    local char = arrayContent:sub(i, i)

    if not inQuotes then
      if char == '"' or char == "'" then
        inQuotes = true
        quoteChar = char
        curObj = curObj .. char
      elseif char == '{' then
        cntBra = cntBra + 1
        if cntBra == 1 then
          curObj = ''
        else
          curObj = curObj .. char
        end
      elseif char == '}' then
        cntBra = cntBra - 1
        if cntBra == 0 then
          if trim(curObj) ~= '' then obs[#obs + 1] = trim(curObj) end
          curObj = ''
        else
          curObj = curObj .. char
        end
      elseif cntBra > 0 then
        curObj = curObj .. char
      end
    else
      curObj = curObj .. char
      if char == quoteChar then
        inQuotes = false
        quoteChar = nil
      end
    end
  end

  for _, objContent in ipairs(obs) do
    local obj = {}

    local pairsList = {}
    local curPair = ''
    local inQuotesPair = false
    local quoteCharPair = nil
    local bracketCntPair = 0
    local braceCntPair = 0

    for i = 1, #objContent do
      local char = objContent:sub(i, i)

      if not inQuotesPair then
        if char == '"' or char == "'" then
          inQuotesPair = true
          quoteCharPair = char
          curPair = curPair .. char
        elseif char == '[' then
          bracketCntPair = bracketCntPair + 1
          curPair = curPair .. char
        elseif char == ']' then
          bracketCntPair = bracketCntPair - 1
          curPair = curPair .. char
        elseif char == '{' then
          braceCntPair = braceCntPair + 1
          curPair = curPair .. char
        elseif char == '}' then
          braceCntPair = braceCntPair - 1
          curPair = curPair .. char
        elseif char == ',' and bracketCntPair == 0 and braceCntPair == 0 then
          local pair = trim(curPair)
          if pair ~= '' then pairsList[#pairsList + 1] = pair end
          curPair = ''
        else
          curPair = curPair .. char
        end
      else
        curPair = curPair .. char
        if char == quoteCharPair then
          inQuotesPair = false
          quoteCharPair = nil
        end
      end
    end

    local trimmedPair = trim(curPair)
    if trimmedPair ~= '' then pairsList[#pairsList + 1] = trimmedPair end

    for _, pair in ipairs(pairsList) do
      local eqPos = pair:find('=')
      if eqPos then
        local key = trim(pair:sub(1, eqPos - 1))
        local val = trim(pair:sub(eqPos + 1))

        if key:match('^".*"$') or key:match("^'.*'$") then key = key:sub(2, -2) end

        if val:match('^%[.*%]$') then
          obj[key] = parseArrayStrs(val)
        elseif val:match('^%{.*%}$') then
          obj[key] = parseInlineTable(val)
        else
          obj[key] = parseVar(val)
        end
      end
    end

    if next(obj) then rst[nam][#rst[nam] + 1] = obj end
  end

  return rst
end

-- 解析 Array of Tables 格式（如 [[apps]]）
function M.parseArrayOfTables(content, name)
  if not content or content == '' then return {} end

  local itms = {}
  local lines = vim.split(content, '\n')
  local curItm = nil
  local inSec = false
  local pattern = '%[%[' .. name .. '%]%]'
  local i = 1

  while i <= #lines do
    local line = trim(lines[i])

    if line == '' or line:match('^#') then
      i = i + 1
      goto continue
    end

    if line:match('^' .. pattern .. '$') then
      if curItm and next(curItm) then table.insert(itms, curItm) end
      curItm = {}
      inSec = true
      i = i + 1
      goto continue
    end

    if line:match('^%[%[.*%]%]$') or line:match('^%[.*%]$') then
      if curItm and next(curItm) then table.insert(itms, curItm) end
      curItm = nil
      inSec = false
      i = i + 1
      goto continue
    end

    if inSec and curItm then
      local eqPos = line:find('=')
      if eqPos then
        local key = trim(line:sub(1, eqPos - 1))
        local val = trim(line:sub(eqPos + 1))

        if key:match('^".*"$') or key:match("^'.*'$") then key = key:sub(2, -2) end

        -- Handle multiline inline tables
        if val:match('^%{') and not val:match('%}$') then
          -- Start of multiline inline table
          local multilineVal = val
          local braceCnt = 1

          -- Continue reading lines until we find the closing brace
          for j = i + 1, #lines do
            local nextLine = trim(lines[j])
            if nextLine == '' or nextLine:match('^#') then goto continue_multiline end

            multilineVal = multilineVal .. ' ' .. nextLine

            -- Count braces to find the end
            for k = 1, #nextLine do
              local char = nextLine:sub(k, k)
              if char == '{' then
                braceCnt = braceCnt + 1
              elseif char == '}' then
                braceCnt = braceCnt - 1
                if braceCnt == 0 then
                  i = j -- Update line position
                  break
                end
              end
            end

            if braceCnt == 0 then break end
            ::continue_multiline::
          end

          if multilineVal:match('^%{.*%}$') then
            curItm[key] = parseInlineTable(multilineVal)
          else
            curItm[key] = parseVar(multilineVal)
          end
        elseif val:match('^%[.*%]$') then
          curItm[key] = parseArrayStrs(val)
        elseif val:match('^%{.*%}$') then
          curItm[key] = parseInlineTable(val)
        else
          curItm[key] = parseVar(val)
        end
      end
    end

    i = i + 1
    ::continue::
  end

  if curItm and next(curItm) then table.insert(itms, curItm) end

  return itms
end

-- 特定的 acts 陣列解析器（向後相容）
function M.parse(content)
  local rst = M.parseArray(content, 'acts')
  return rst
end

return M
