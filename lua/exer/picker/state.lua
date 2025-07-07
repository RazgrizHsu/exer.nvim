local M = {}

M.ste = {
  listWin = nil,
  listBuf = nil,
  inputWin = nil,
  inputBuf = nil,
  opts = {},
  filteredOpts = {},
  selectedIdx = 1,
  query = '',
  onConfirm = nil,
  originalFile = nil,
  scrollOffset = 0,
}

function M.reset()
  M.ste.listWin = nil
  M.ste.listBuf = nil
  M.ste.inputWin = nil
  M.ste.inputBuf = nil
  M.ste.opts = {}
  M.ste.filteredOpts = {}
  M.ste.selectedIdx = 1
  M.ste.query = ''
  M.ste.onConfirm = nil
  M.ste.originalFile = nil
  M.ste.scrollOffset = 0
end

function M.isListWinValid() return M.ste.listWin and vim.api.nvim_win_is_valid(M.ste.listWin) end
function M.isInputWinValid() return M.ste.inputWin and vim.api.nvim_win_is_valid(M.ste.inputWin) end
function M.isListBufValid() return M.ste.listBuf and vim.api.nvim_buf_is_valid(M.ste.listBuf) end
function M.isInputBufValid() return M.ste.inputBuf and vim.api.nvim_buf_is_valid(M.ste.inputBuf) end

return M
