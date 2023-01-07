local M = {}

local api = vim.api

local popup = require("infra.popup")
local jelly = require("infra.jellyfish")("popupshell")
local bufrename = require("infra.bufrename")
local ex = require("infra.ex")

M.tmux = function()
  if not os.getenv("TMUX") then
    jelly.err("requires tmux to display popup window")
    return
  end

  local cwd = vim.fn.expand("%:p:h")
  local cmd = string.format([[tmux display-popup -EE -d %s]], cwd)
  local file = io.popen(cmd)
  if file ~= nil then file:close() end
end

local state = {
  term_bufnr = nil,
  term_chan = nil,

  ---@param self table
  is_term_valid = function(self)
    return self.term_bufnr ~= nil and api.nvim_buf_is_valid(self.term_bufnr)
  end,
}

M.floatwin = function()
  -- get cwd from original buffer
  local cwd = vim.fn.expand("%:p:h")
  local need_init_term = not state:is_term_valid()

  if need_init_term then
    -- create the buffer of terminal
    local bufnr = api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, "create new buffer failed")
    state.term_bufnr = bufnr
  end

  -- create the floatwin
  do
    local width, height, row, col = popup.coordinates(0.8, 0.6)

    -- stylua: ignore
    local win_id = api.nvim_open_win(state.term_bufnr, true, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, row = row, col = col,
    })
    assert(win_id ~= 0, "open new win failed")
    -- no special highlight
    api.nvim_win_set_option(win_id, "winhl", "NormalFloat:Normal")

    api.nvim_create_autocmd("WinLeave", {
      buffer = state.term_bufnr,
      once = true,
      callback = function()
        api.nvim_win_close(win_id, true)
      end,
    })

    -- keybinds for close the floatwin
    local close_win = string.format([[<cmd>lua vim.api.nvim_win_close(%s, false)<cr>]], win_id)
    api.nvim_buf_set_keymap(state.term_bufnr, "n", "q", close_win, { noremap = true })
    api.nvim_buf_set_keymap(state.term_bufnr, "n", "<c-]>", close_win, { noremap = true })
  end

  if need_init_term then
    -- init term after all operations are done
    api.nvim_buf_call(state.term_bufnr, function()
      state.term_chan = vim.fn.termopen(vim.env["SHELL"] or "/bin/sh", { cwd = cwd })
    end)
    bufrename(state.term_bufnr, string.format("term://%d", state.term_chan))
  end

  ex("startinsert")
end

return M
