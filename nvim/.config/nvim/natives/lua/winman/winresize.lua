-- rewrite of the following vimscript
--[[
" Interactively change the window size
function! InteractiveResizeWindow()
  let char = "s"
  while char =~ '^\w$'
    echo "(InteractiveResizeWindow) TYPE: h,j,k,l to resize or a for auto resize"
    let char = getcharstr()
    if char == "h" | vertical res -5 | endif
    if char == "l" | vertical res +5 | endif
    if char == "j" | res -5 | endif
    if char == "k" | res +5 | endif
    redraw
  endwhile
endfunction
--]]

local ex = require("infra.ex")
local setlib = require("infra.setlib")
local tty = require("infra.tty")

local resize = {
  h = "vertical resize -5",
  l = "vertical resize +5",
  j = "resize -5",
  k = "resize +5",
  --
  H = "vertical resize -999",
  L = "vertical resize +999",
  J = "resize -999",
  K = "resize +999",
  --
  ["="] = "wincmd =",
}

--esc,spc,cr
local terminate = setlib.new(0x1b, 0x20, 0x0d)

return function()
  for char, code in tty.read_raw do
    if resize[char] then
      ex.eval(resize[char])
      ex("redraw")
    elseif terminate[code] then
      break
    else
      --silently ignore other inputs
    end
  end
end
