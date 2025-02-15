local m = require("infra.keymap.global")

local batteries = require("batteries")

do -- main
  local global = vim.g

  if batteries.has("easy-align") then -- easy-align
    m.x("<cr>", "<Plug>(EasyAlign)")
  end

  do -- man
    global.ft_man_folding_enable = true
  end

  if batteries.has("surround") then
    global.surround_no_mappings = 1
    m.n("dS", "<Plug>Dsurround")
    m.n("cS", "<Plug>Csurround")
    m.n("yS", "<Plug>Ysurround")
  end
end
