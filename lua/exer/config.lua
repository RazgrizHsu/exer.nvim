local M = {}

local defaults = {
  debug = false,
  disable_default_keymaps = false,
  config_files = nil,
  ui = {
    height = 0.3,
    list_width = 36,
    auto_toggle = true,
    auto_scroll = true,
  },
  keymaps = {
    { '<leader>ro', 'ExerOpen', 'Open task picker' },
    { '<leader>rr', 'ExerRedo', 'Re-run last task' },
    { '<leader>rx', 'ExerStop', 'Stop all running tasks' },
    { '<A-/>', 'ExerShow', 'Toggle task output window' },
    { '<C-w>t', 'ExerFocusUI', 'Focus task UI' },
    { '<C-j>', 'ExerNavDown', 'Smart navigate down' },
    { '<C-k>', 'ExerNavUp', 'Smart navigate up' },
    { '<C-h>', 'ExerNavLeft', 'Smart navigate left' },
    { '<C-l>', 'ExerNavRight', 'Smart navigate right' },
  },
}

local options = nil

function M.setup(opts)
  opts = opts or {}
  options = vim.tbl_deep_extend('force', defaults, opts)

  if options.debug then _G.g_exer_debug = true end

  if options.ui then require('exer.ui').setup(options.ui) end

  M.setupKeymaps()
end

function M.get()
  if options == nil then M.setup() end
  return options
end

function M.setupKeymaps()
  if options.disable_default_keymaps then return end

  local hasLazyKeys = false
  if package.loaded.lazy then
    local ok, lazy_config = pcall(require, 'lazy.core.config')
    if ok and lazy_config.spec and lazy_config.spec.plugins then
      for _, plugin in pairs(lazy_config.spec.plugins) do
        if plugin.name == 'exer.nvim' and plugin.keys then
          hasLazyKeys = true
          break
        end
      end
    end
  end

  if not hasLazyKeys then
    for _, keyDef in ipairs(options.keymaps) do
      local lhs, cmd, desc = keyDef[1], keyDef[2], keyDef[3]
      local existing = vim.fn.maparg(lhs, 'n', false, false)
      if existing == '' then vim.api.nvim_set_keymap('n', lhs, '<cmd>' .. cmd .. '<cr>', {
        noremap = true,
        silent = true,
        desc = desc,
      }) end
    end
  end
end

return M
