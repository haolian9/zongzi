local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

-- why: i recently faced obvious lagging when use vimwiki
--
-- spec:
-- * link: [[parent/file]], [[file]]
-- * that's all
-- * no syntax, no highlight, no autocmd, no ftplugin
--

local M = {}

---@param bufnr integer
function M.attach(bufnr)
  local bo = prefer.buf(bufnr)
  bo.syntax = "wiki"
  bo.suffixesadd = ".wiki"
  bo.textwidth = 90
  bo.formatoptions = bo.formatoptions .. "]"
  bo.shiftwidth = 2
  bo.tabstop = 2
  bo.softtabstop = 2

  local bm = bufmap.wraps(bufnr)
  bm.n("<cr>", function() require("wiki.rhs").edit_link() end)
  bm.n("<c-]>", function()
    require("infra.winsplit")("right")
    require("wiki.rhs").edit_link()
  end)
  bm.i("<cr>", function()
    if require("buds")() then return end
    feedkeys.codes("\r", "n")
  end)

  ex("runtime", "syntax/wiki.vim")
end

return M
