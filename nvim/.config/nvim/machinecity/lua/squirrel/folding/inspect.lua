local api = vim.api
local exprs = require("squirrel.folding.exprs")
local ex = require("infra.ex")

return function()
  local win_id = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(win_id)

  local new_bufnr
  do
    local ft = api.nvim_buf_get_option(bufnr, "filetype")
    ---@type squirrel.folding.fold_expr
    local foldexpr = assert(exprs[ft], "unsupported ft")

    local line_count = api.nvim_buf_line_count(bufnr)
    new_bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(new_bufnr, "bufhidden", "wipe")
    local lines = {}
    for i = 0, line_count do
      local lv = foldexpr(i)
      table.insert(lines, string.format("%s|%d", string.rep(" ", lv), lv))
    end
    api.nvim_buf_set_lines(new_bufnr, 0, -1, false, lines)
  end

  local new_win_id
  -- setup new win & buf
  do
    ex("leftabove vsplit")
    new_win_id = api.nvim_get_current_win()
    api.nvim_win_set_width(new_win_id, 20)
    local wo = vim.wo[new_win_id]
    wo.number = true
    wo.relativenumber = false
    api.nvim_win_set_buf(new_win_id, new_bufnr)
  end

  -- scrollbind
  api.nvim_win_set_cursor(new_win_id, api.nvim_win_get_cursor(win_id))
  api.nvim_win_set_option(win_id, "scrollbind", true)
  api.nvim_win_set_option(new_win_id, "scrollbind", true)
end
