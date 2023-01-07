---@diagnostic disable: undefined-global
require("infra.ftctx")(function()
  bo.filetype = "wiki"
  bo.suffixesadd = '.wiki'
  ex("runtime", "syntax/wiki.vim")

  wo.conceallevel = 3

  bo.textwidth = 90
  bopt.formatoptions:append("]")

  bo.shiftwidth = 2
  bo.tabstop = 2
  bo.softtabstop = 2

  nnoremap([[<cr>]], function()
    require("wiki").edit_link()
  end)

  nnoremap([[<c-]>]], function()
    require("infra.ex")("rightbelow vsplit")
    require("wiki").edit_link()
  end)
end)
