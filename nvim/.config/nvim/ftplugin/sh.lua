---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.suffixesadd = ".sh"
  bo.comments = [[b:#,fb:-]]
  bo.commentstring = [[# %s]]

  vnoremap("g>", [[:lua require'squirrel.veil'.cover('sh')<cr>]])
end)
