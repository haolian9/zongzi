local M = {}

local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

local api = vim.api

function M.attach(ft)
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local spec
  do
    ft = ft or prefer.bo(bufnr, "filetype")
    if ft == "lua" then
      spec = require("squirrel.jumps.luaspec")
    elseif ft == "zig" then
      spec = require("squirrel.jumps.zigspec")
    else
      error("unsupported ft=" .. ft)
    end
  end

  local bm = bufmap.wraps(bufnr)

  for lhs, rhs in pairs(spec.objects) do
    bm.x(lhs, rhs)
    bm.o(lhs, rhs)
  end

  for lhs, rhs in pairs(spec.motions) do
    bm.n(lhs, rhs)
  end

  if spec.goto_peer ~= nil then bm.n("%", spec.goto_peer) end
end

return M
