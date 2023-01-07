---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.suffixesadd = ".zig"
  bo.commentstring = "// %s"

  vnoremap("g>", [[:lua require'squirrel.veil'.cover('zig')<cr>]])
  nnoremap([[vin]], [[<cmd>lua require'squirrel.incsel'()<cr>]])

  require("squirrel.jumps").attach("zig")
  require("squirrel.folding").attach("zig")
end)
