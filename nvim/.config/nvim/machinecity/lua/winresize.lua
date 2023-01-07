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

return function()
  local need_redraw = true
  while true do
    local code = vim.fn.getchar()
    need_redraw = true
    if code == 0x68 then
      -- h
      ex("vertical resize -5")
    elseif code == 0x6a then
      -- j
      ex("resize -5")
    elseif code == 0x6b then
      -- k
      ex("resize +5")
    elseif code == 0x6c then
      -- l
      ex("vertical resize +5")
    else
      need_redraw = false
      break
    end
    if need_redraw then ex("redraw") end
    need_redraw = false
  end
  if need_redraw then ex("redraw") end
end
