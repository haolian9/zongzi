---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.suffixesadd = ".py"
  bo.comments = [[b:#,fb:-]]
  bo.commentstring = [[# %s]]

  nnoremap([[<leader>i]], [[<cmd>lua require'squirrel.imports'()<cr>]])
  nnoremap([[vin]], [[<cmd>lua require'squirrel.incsel'()<cr>]])

  require("squirrel.folding").attach("python")
end)
