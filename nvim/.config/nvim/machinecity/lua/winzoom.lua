-- inspired by tmux's <prefix>-z
--
-- maybe: consider tabline, statusline, cmdline?
--
-- limits:
-- * window will be closed on :sp, :vs, :help
--

local api = vim.api
local sync = require("infra.sync_primitives")

local mutex = sync.create_mutex()

local function zoom(bufnr)
  if bufnr == nil or bufnr == 0 then bufnr = api.nvim_get_current_buf() end

  if not mutex:acquire_nowait() then error("zoomed one alreay") end

  -- stylua: ignore
  local win_id = api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 0, col = 0, width = vim.o.columns, height = vim.o.lines,
  })
  api.nvim_win_set_option(win_id, "winhl", "NormalFloat:Normal")

  api.nvim_create_autocmd("WinLeave", {
    once = true,
    callback = function()
      api.nvim_win_close(win_id, false)
      mutex:release()
    end,
  })
end

return zoom
