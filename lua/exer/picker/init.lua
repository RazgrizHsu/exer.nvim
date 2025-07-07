local M = {}

local state = require('exer.picker.state')
local window = require('exer.picker.window')
local render = require('exer.picker.render')
local filter = require('exer.picker.filter')
local nav = require('exer.picker.nav')

function M.pick(config)
  local opts = config.items or {}
  local onConfirm = config.confirm or function(_) end

  state.ste.opts = opts
  state.ste.query = ''
  state.ste.selectedIdx = 1
  state.ste.onConfirm = onConfirm
  state.ste.originalFile = config.original_file

  filter.filterOpts()

  local listBuf, listWin, listWinOpts = window.createListWindow(#opts)
  local inputBuf, inputWin = window.createInputWindow(listWinOpts)

  state.ste.listBuf = listBuf
  state.ste.listWin = listWin
  state.ste.inputBuf = inputBuf
  state.ste.inputWin = inputWin

  nav.setKeymaps()
  render.renderPicker()
  nav.setupAutoClose()
  vim.cmd('startinsert')
end

function M.show()
  local co = require('exer.core')

  co.log.debug('=== UI PICKER OPENED ===', 'Picker')

  local uv = vim.uv
  if uv.os_homedir() == uv.cwd() then
    co.utils.msg('Home is not allowed as working dir.', vim.log.levels.WARN, {})
    return
  end

  local fileCur = vim.fn.expand('%:p')

  local uts = require('exer.core.utils')
  local mods = require('exer.mods')
  local proj = require('exer.proj')

  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })

  co.log.debug('Current file: ' .. fileCur, 'Picker')
  co.log.debug('Current filetype: ' .. (ft or 'nil'), 'Picker')

  local optsLang = {}

  -- add proj tasks (highest priority)
  local projActs = proj.getActs(ft)
  co.log.debug('Found ' .. #projActs .. ' proj tasks', 'Picker')

  local validProjCount = 0
  for _, act in ipairs(projActs) do
    if act and type(act) == 'table' and act.id and act.id ~= '' then
      if act.cmd and (type(act.cmd) == 'string' or (type(act.cmd) == 'table' and #act.cmd > 0)) then
        validProjCount = validProjCount + 1
        local desc = act.desc and (' - ' .. act.desc) or ''
        table.insert(optsLang, {
          text = act.id,
          desc = act.desc,
          value = act.id,
          type = 'Proj',
          name = act.id,
          act = act,
        })
      else
        co.log.debug(string.format('Skipping proj act with invalid cmd: %s', act.id), 'Picker')
      end
    end
  end

  co.log.debug(string.format('Added %d valid proj tasks out of %d', validProjCount, #projActs), 'Picker')

  -- add module tasks (languages, build tools and test frameworks)
  local optsMods = mods.getOpts(ft)
  co.log.debug('Found ' .. #optsMods .. ' mods options', 'Picker')

  -- add separator only if both proj tasks and mod tasks exist
  if #projActs > 0 and #optsMods > 0 then table.insert(optsLang, { text = '', value = 'separator' }) end

  for _, item in ipairs(optsMods) do
    table.insert(optsLang, item)
  end

  co.log.debug('Total options available: ' .. #optsLang, 'Picker')

  -- 過濾掉任何可能的 nil 或無效項目
  local finalOpts = {}
  for _, opt in ipairs(optsLang) do
    if opt and opt.value and opt.text and opt.value ~= 'nil' and opt.value ~= '' and type(opt.text) == 'string' and opt.text ~= 'nil' then table.insert(finalOpts, opt) end
  end
  optsLang = finalOpts

  local hasOpts = false
  for _, opt in ipairs(optsLang) do
    if opt.value ~= 'separator' then
      hasOpts = true
      break
    end
  end

  if not hasOpts then
    local razFiletypes = {
      ['raz-panel'] = true,
      ['raz-tasks'] = true,
      ['raz-picker-list'] = true,
      ['raz-picker-input'] = true,
    }

    if razFiletypes[ft] then
      co.utils.msg('Please move to a project file before running', vim.log.levels.INFO, {})
    else
      co.utils.msg(string.format('No exer options available for filetype: "%s"', ft or 'nil'), vim.log.levels.WARN, {})
    end
    return
  end

  -- Remove old numbering logic - numbers are now handled in render.lua

  local function onPick(item)
    if not item or item.value == '' or item.value == 'separator' then return end

    if item.type == 'Proj' then
      -- Execute proj task
      local rnr = require('exer.core.runner')
      local act = item.act
      local cmd = proj.expandVars(act.cmd)
      local env = act.env or {}
      local cwd = act.cwd or vim.fn.getcwd() -- Default to current working directory (project root)

      if type(cmd) == 'table' then
        for i, c in ipairs(cmd) do
          local taskName = string.format('[proj] %s (%d/%d)', act.id, i, #cmd)
          rnr.run({ name = taskName, cmd = c, env = env, cwd = cwd })
        end
      else
        local taskName = string.format('[proj] %s', act.id)
        rnr.run({ name = taskName, cmd = cmd, env = env, cwd = cwd })
      end
    else
      -- Execute mods task (languages, build tools, test frameworks)
      local ok, ex = pcall(mods.runAct, item.value)
      if not ok then co.utils.msg('Failed to execute action: ' .. tostring(ex), vim.log.levels.ERROR) end
    end
  end

  M.pick({
    items = optsLang,
    confirm = onPick,
    original_file = fileCur,
  })
end

return M
