local M = {}

function M.msg(message, level, opts)
  opts = opts or {}
  opts.title = opts.title or 'Exer.nvim'
  vim.notify(message, level, opts)
end

---@param dirS string
---@param nameF string
---@param surround boolean|nil
---@return table
function M.findFiles(dirS, nameF, surround)
  if not dirS or not nameF then return {} end
  local files = {}

  local cmdFind
  if string.sub(package.config, 1, 1) == '\\' then
    cmdFind = string.format('powershell.exe -Command "Get-ChildItem -Path \\"%s\\" -Recurse -Filter \\"%s\\" -File -Exclude \\".git\\" -ErrorAction SilentlyContinue"', dirS, nameF)
  else
    cmdFind = string.format('find "%s" -type d -name ".git" -prune -o -type f -name "%s" -print 2>/dev/null', dirS, nameF)
  end
  local pipe = io.popen(cmdFind, 'r')
  if pipe then
    for pathF in pipe:lines() do
      if surround then
        table.insert(files, '"' .. pathF .. '"')
      else
        table.insert(files, pathF)
      end
    end
    pipe:close()
  end

  return files
end

---@param epPath string|nil
---@param pattern string
---@return string
function M.findFilesToCompile(epPath, pattern)
  if not epPath or not pattern then return '' end
  local dirEp = vim.fn.fnamemodify(epPath, ':h')
  local files = M.findFiles(dirEp, pattern, true)
  local filesStr = table.concat(files, ' ')

  return filesStr
end

---@return boolean|nil
function M.fileExists(filename)
  local stat = vim.uv.fs_stat(filename)
  return stat and stat.type == 'file'
end

---Given a string, convert 'slash' to 'inverted slash' if on windows, and vice versa on UNIX.
---Then return the resulting string surrounded by "".
---
---This way the shell will be able to detect spaces in the path.
---@param path string|nil A path string.
---@param surround boolean|nil If true, surround path by "". False by default.
---@param fallback string|nil Fallback value if path is nil.
---@return string|nil,nil path A path string formatted for the current OS.
function M.osPath(path, surround, fallback)
  if path == nil then return fallback end
  if surround == nil then surround = false end

  local separator = string.sub(package.config, 1, 1)

  if surround then path = '"' .. path .. '"' end

  return string.gsub(path, '[/\\]', separator)
end

---@param pathApp string
---@return string
function M.getDirTests(pathApp)
  local dirPlug = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
  return M.osPath(dirPlug .. '/tests/' .. pathApp) or (dirPlug .. '/tests/' .. pathApp)
end

return M
