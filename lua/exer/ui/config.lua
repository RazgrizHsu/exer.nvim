local M = {}

local _cfgDefaults = {
  height = 0.3, -- UI height (number or float for percentage)
  list_width = 36, -- Task list width (number or float for percentage)
  auto_toggle = false, -- Auto show detail on open
  auto_scroll = true, -- Auto scroll to bottom
}

local _cfg = {}

M.height = nil
M.list_width = nil
M.auto_toggle = nil
M.auto_scroll = nil

function M.setup(opts)
  _cfg = vim.tbl_deep_extend('force', _cfgDefaults, opts or {})

  M.height = _cfg.height
  M.list_width = _cfg.list_width
  M.auto_toggle = _cfg.auto_toggle
  M.auto_scroll = _cfg.auto_scroll

  return _cfg
end

function M.get(key)
  if key then return _cfg[key] end
  return _cfg
end

function M.all() return _cfg end
function M.getDefaults() return _cfgDefaults end

M.height = _cfgDefaults.height
M.list_width = _cfgDefaults.list_width
M.auto_toggle = _cfgDefaults.auto_toggle
M.auto_scroll = _cfgDefaults.auto_scroll

return M
