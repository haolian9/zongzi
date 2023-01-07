local M = {}

local api = vim.api

local popup = require("infra.popup")
local fn = require("infra.fn")

M.popup = function(...)
  -- let inspect crash first
  local text = {}
  for arg in fn.list_iter({ ... }) do
    table.insert(text, vim.inspect(arg))
  end

  local bufnr = api.nvim_create_buf(false, true)
  assert(bufnr ~= 0, "create new buffer failed")
  api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  -- create the floatwin
  do
    local width, height, row, col = popup.coordinates(0.7, 0.9)
    local win_focus = true

    -- stylua: ignore
    local win_id = api.nvim_open_win(bufnr, win_focus, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, row = row, col = col,
    })
    assert(win_id ~= 0, "open new win failed")
    api.nvim_win_set_option(win_id, "winhl", "NormalFloat:Normal")

    api.nvim_create_autocmd("WinLeave", {
      buffer = bufnr,
      once = true,
      callback = function()
        api.nvim_win_close(win_id, true)
      end,
    })
  end

  do
    local start = 0
    local iter = fn.iter_chained(fn.map(function(el)
      return fn.split_iter(el, "\n", nil, false)
    end, text))
    for lines in fn.batch(iter, 30) do
      api.nvim_buf_set_lines(bufnr, start, start + #lines, false, lines)
      start = start + #lines
    end
  end
end

return M
