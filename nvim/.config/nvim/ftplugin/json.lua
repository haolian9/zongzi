---@diagnostic disable: undefined-global
require("ftctx")(function()
  nnoremap("gq", "<cmd>%! jq .<cr>")

  require("squirrel.folding").attach("json")
end)
