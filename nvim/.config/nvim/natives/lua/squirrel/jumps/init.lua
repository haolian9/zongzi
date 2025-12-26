local M = {}

local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local oop = require("infra.oop")
local prefer = require("infra.prefer")

local specs = oop.lazyattrs({}, function(ft)
  local modname = string.format("squirrel.jumps.%sspec", ft)
  return require(modname)
end)

function M.attach(ft)
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  ft = ft or prefer.bo(bufnr, "filetype")

  local spec = assert(specs[ft], ft)

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
