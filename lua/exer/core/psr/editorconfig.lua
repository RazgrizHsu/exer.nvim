local M = {}

function M.extractExerSection(content)
  if not content or content == '' then return nil end

  local lines = vim.split(content, '\n')
  local inExerSection = false
  local exerContent = {}
  local currentSection = nil

  local log = require('exer.core').lg
  log.debug('[editorconfig] Extracting exer section from ' .. #lines .. ' lines')

  for _, line in ipairs(lines) do
    local trimmedLine = line:match('^%s*(.-)%s*$')

    -- Check for section headers
    if trimmedLine:match('^%[%[exer%.acts%]%]') then
      -- TOML array of tables format
      log.debug('[editorconfig] Found [[exer.acts]] section')
      inExerSection = true
      currentSection = 'toml_array'
      table.insert(exerContent, trimmedLine)
    elseif trimmedLine:match('^%[exer%]') then
      -- [exer] section
      log.debug('[editorconfig] Found [exer] section')
      inExerSection = true
      currentSection = 'exer'
      table.insert(exerContent, trimmedLine)
    elseif trimmedLine:match('^%[exer%.acts%]') then
      -- [exer.acts] INI style section
      log.debug('[editorconfig] Found [exer.acts] section')
      inExerSection = true
      currentSection = 'exer_acts'
      table.insert(exerContent, trimmedLine)
    elseif inExerSection then
      -- Check if we hit a new section that's not exer-related
      if trimmedLine:match('^%[') and not trimmedLine:match('^%[%[?exer%.') then break end
      table.insert(exerContent, line)
    end
  end

  if #exerContent == 0 then return nil end

  return table.concat(exerContent, '\n'), currentSection
end

-- Parse INI-style [exer.acts] sections into TOML format
function M.convertIniToToml(content)
  if not content then return nil end

  local lines = vim.split(content, '\n')
  local acts = {}
  local currentAct = nil

  for _, line in ipairs(lines) do
    local trimmedLine = line:match('^%s*(.-)%s*$')

    if trimmedLine:match('^%[exer%.acts%]') then
      -- New [exer.acts] section starts a new act
      if currentAct and currentAct.id then table.insert(acts, currentAct) end
      currentAct = {}
    elseif trimmedLine:match('^#') or trimmedLine:match('^;') then
      -- Skip comments
    elseif trimmedLine ~= '' and currentAct then
      -- Parse key = value
      local key, value = trimmedLine:match('^([^=]+)%s*=%s*(.+)$')
      if key and value then
        key = key:match('^%s*(.-)%s*$')
        value = value:match('^%s*(.-)%s*$')

        -- Handle array format: [ "a", "b" ]
        if value:match('^%[.*%]$') then
          -- Keep array format as is for TOML conversion
          currentAct[key] = value
        else
          -- Remove quotes if present for string values
          if value:match('^".*"$') or value:match("^'.*'$") then value = value:sub(2, -2) end
          currentAct[key] = value
        end
      end
    end
  end

  -- Don't forget the last act
  if currentAct and currentAct.id then table.insert(acts, currentAct) end

  -- Convert to TOML format
  if #acts > 0 then
    local tomlLines = {}
    for _, act in ipairs(acts) do
      table.insert(tomlLines, '[[exer.acts]]')
      for k, v in pairs(act) do
        -- Check if value is an array format
        if v:match('^%[.*%]$') then
          table.insert(tomlLines, string.format('%s = %s', k, v))
        else
          table.insert(tomlLines, string.format('%s = "%s"', k, v))
        end
      end
      table.insert(tomlLines, '')
    end
    return table.concat(tomlLines, '\n')
  end

  return nil
end

return M
