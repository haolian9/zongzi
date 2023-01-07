local M = {}

local api = vim.api

function M.attach(ft)
  local win_id = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(win_id)

  local spec
  do
    ft = ft or api.nvim_buf_get_option(bufnr, "filetype")
    if ft == "lua" then
      spec = require("squirrel.jumps.luaspec")
    elseif ft == "zig" then
      spec = require("squirrel.jumps.zigspec")
    else
      error("unsupported ft=" .. ft)
    end
  end

  for lhs, rhs in pairs(spec.objects) do
    api.nvim_buf_set_keymap(bufnr, "x", lhs, "", { noremap = true, callback = rhs })
    api.nvim_buf_set_keymap(bufnr, "o", lhs, "", { noremap = true, callback = rhs })
  end

  for lhs, rhs in pairs(spec.motions) do
    api.nvim_buf_set_keymap(bufnr, "n", lhs, "", { noremap = true, callback = rhs })
  end

  if spec.goto_peer ~= nil then api.nvim_buf_set_keymap(bufnr, "n", "%", "", { noremap = true, callback = spec.goto_peer }) end
end

return M
