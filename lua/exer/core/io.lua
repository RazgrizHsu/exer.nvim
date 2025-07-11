local M = {}
local utils = require('exer.core.utils')

---Check if file exists and is readable
---@param path string File path
---@return boolean
function M.fileExists(path) return vim.fn.filereadable(path) == 1 end

---Check if directory exists
---@param path string Directory path
---@return boolean
function M.dirExists(path) return vim.fn.isdirectory(path) == 1 end

---Read file content
---@param path string File path
---@return string|nil File content, nil if failed
function M.readFile(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local cnt = file:read('*all')
  file:close()
  return cnt
end

---Read and parse JSON file
---@param path string JSON file path
---@return table|nil Parsed table, nil if failed
function M.readJson(path)
  local cnt = M.readFile(path)
  if not cnt then return nil end

  local psr = require('exer.core').psr
  local ok, rst = pcall(psr.json.decode, cnt)
  if not ok then
    utils.msg('Error decoding JSON: ' .. path .. ' - ' .. tostring(rst), vim.log.levels.WARN)
    return nil
  end

  return rst
end

---Find first existing file in multiple paths
---@param pathWorkDir string Working directory
---@param filenames table List of filenames to search
---@return string|nil Full path of found file, nil if not found
function M.findFile(pathWorkDir, filenames)
  for _, filename in ipairs(filenames) do
    local path = pathWorkDir .. utils.osPath('/' .. filename)
    if M.fileExists(path) then return path end
  end
  return nil
end

---Check if file contains specified text patterns
---@param path string File path
---@param patterns table|string Text patterns to search (string or array of strings)
---@return boolean
function M.fileContains(path, patterns)
  local cnt = M.readFile(path)
  if not cnt then return false end

  if type(patterns) == 'string' then patterns = { patterns } end

  for _, pattern in ipairs(patterns) do
    if cnt:find(pattern) then return true end
  end

  return false
end

---Get project root directory (git root or current working directory)
---@return string Project root path
function M.getRoot()
  local cwd = vim.fn.getcwd()
  local gitRoot = vim.fn.systemlist('git rev-parse --show-toplevel 2>/dev/null')[1]

  if gitRoot and gitRoot ~= '' then return gitRoot end

  return cwd
end

return M
