---@diagnostic disable: undefined-global
require("ftctx")(function()
  -- dash for file-name.lua
  bopt.iskeyword:append("-")

  bo.tabstop = 2
  bo.softtabstop = 2
  bo.shiftwidth = 2
  bo.expandtab = true

  wo.list = true

  vnoremap([[K]], [[:lua require'help'.nvim()<cr>]])
  nnoremap([[gx]], [[<cmd>lua require'squirrel.docgen.lua'()<cr>]])
  vnoremap([[g>]], [[:lua require'squirrel.veil'.cover('lua')<cr>]])
  nnoremap([[vin]], [[<cmd>lua require'squirrel.incsel'()<cr>]])

  require("squirrel.jumps").attach("lua")
  require("squirrel.folding").attach("lua")
end)
