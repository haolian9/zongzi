-- inspired by tmux's <prefix>-z
--
-- design choices
-- * fullscreen, no tabline, statusline, cmdline
-- * window will be closed on :sp, :vs, :help
--

local rifts = require("infra.rifts")

local api = vim.api

local winid

-- toggle zoom in/out a window, intended not for buffer
return function()
  if winid and api.nvim_win_is_valid(winid) then
    assert(winid == api.nvim_get_current_win())
    api.nvim_win_close(winid, false)
    winid = nil
  else
    local bufnr = api.nvim_get_current_buf()
    rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
  end
end
