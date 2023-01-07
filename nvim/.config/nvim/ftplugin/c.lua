---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.suffixesadd = ".c"
  -- todo: &comments
  bo.commentstring = [[// %s]]
  bo.expandtab = true
  bo.cindent = true

  nnoremap([[gq]], [[<cmd>lua vim.lsp.buf.format{async = true}<cr>]])
  vnoremap([[g>]], [[:lua require'squirrel.veil'.cover('c')<cr>]])
  nnoremap([[vin]], [[<cmd>lua require'squirrel.incsel'()<cr>]])

  require("squirrel.folding").attach("c")
end)
