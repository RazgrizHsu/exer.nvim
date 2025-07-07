local M = {}

function M.apply(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_call(
    buf,
    function()
      vim.cmd([[
      syntax clear

      " Task headers and status
      syn match RazLogTaskHeader '^\(▶\|✓\|✗\|⏸\) Task #\d\+:'
      syn match RazLogSuccess '✓'
      syn match RazLogError '✗'
      syn match RazLogRunning '▶'
      syn match RazLogPending '⏸'

      syn match RazLogInfo '\v\c<(info|done|success|completed)>\ze(\s|$|[^\w])|✓'
      syn match RazLogWarn '\v\c<(warn|warning)>\ze(\s|$|[^\w])|⚠'
      syn match RazLogError '\v\c<(error|fail|failed|exception)>\ze(\s|$|[^\w])|✗'
      syn match RazLogDebug '\v\c<(debug|trace)>\ze(\s|$|[^\w])'

      " Highlight exit codes
      syn match RazLogExitSuccess 'ExitCode: 0'
      syn match RazLogExitError 'ExitCode: [1-9]\d*'

      " Highlight timestamps and durations
      syn match RazLogTime '\v\d+(\.\d+)?[smh](\d+(\.\d+)?[smh])*'
      syn match RazLogDuration 'Duration: \S\+'

      " Highlight commands and paths
      syn match RazLogCommand '\v^Command:'
      syn match RazLogStatus '\v^Status:'
      syn match RazLogStartTime '\v^StartTime:'
      syn match RazLogEndTime '\v^EndTime:'
      syn match RazLogPath '\v[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)+' 
      syn match RazLogPath '\v/[^ ]*'
      syn match RazLogSeparator '^─\+$'

      syn match RazLogOutput '^Output:$'

      " Highlight UI elements
      syn match RazLogTitle '^Task Panel$'
      syn match RazLogInstruction '^Select a task'
      syn match RazLogKeysHeader '^Keys:$'
      syn match RazLogKeyBinding '^\s\+<.*> -'

      " Set colors
      hi default link RazLogTaskHeader Title
      hi default link RazLogSuccess String
      hi default link RazLogError ErrorMsg
      hi default link RazLogRunning Function
      hi default link RazLogPending Comment
      hi default link RazLogInfo String
      hi default link RazLogWarn WarningMsg
      hi default link RazLogDebug Comment
      hi default link RazLogExitSuccess String
      hi default link RazLogExitError ErrorMsg
      hi default link RazLogTime Number
      hi default link RazLogDuration Special
      hi default link RazLogCommand Keyword
      hi default link RazLogStatus Keyword
      hi default link RazLogStartTime Keyword
      hi default link RazLogEndTime Keyword
      hi default link RazLogPath Directory
      hi default link RazLogSeparator Comment
      hi default link RazLogOutput Title
      hi default link RazLogTitle Title
      hi default link RazLogInstruction Comment
      hi default link RazLogKeysHeader Keyword
      hi default link RazLogKeyBinding Special
    ]])
    end
  )
end

return M
