---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.suffixesadd = ".go"
  bo.commentstring = [[// %s]]
  bo.expandtab = false

  nnoremap([[<leader>i]], [[<cmd>lua require'squirrel.imports'()<cr>]])
  vnoremap([[g>]], [[:lua require'squirrel.veil'.cover('go')<cr>]])
  nnoremap([[vin]], [[<cmd>lua require'squirrel.incsel'()<cr>]])
  nnoremap([[gx]], [[<cmd>lua require'squirrel.docgen.go'()<cr>]])

  require("squirrel.folding").attach("go")
end)
