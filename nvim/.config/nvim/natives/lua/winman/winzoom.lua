-- inspired by tmux's <prefix>-z
--
-- design choices
-- * fullscreen, no tabline, statusline, cmdline
-- * window will be closed on :sp, :vs, :help
--

local ni = require("infra.ni")
local rifts = require("infra.rifts")

local winid

-- toggle zoom in/out a window, intended not for buffer
return function()
  if winid and ni.win_is_valid(winid) then
    assert(winid == ni.get_current_win())
    ni.win_close(winid, false)
    winid = nil
  else
    local bufnr = ni.get_current_buf()
    rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
  end
end
