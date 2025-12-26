local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("infra.handyclosekeys", "info")
local bufmap = require("infra.keymap.buffer")
local mi = require("infra.mi")

local function close_current_win_if_float()
  if mi.win_is_landed(0) then return jelly.info("refuse to close a landed window, try :q") end
  return ex("quit")
end

---map n{q,esc,c-[,c-]} to quit, meant to be used to floatwins
---@param bufnr integer
---@param float_only? boolean @nil=true; only close a window when it's nonfloat/landed.
return function(bufnr, float_only)
  if float_only == nil then float_only = true end

  local bm = bufmap.wraps(bufnr)
  local rhs = float_only and close_current_win_if_float or "<cmd>q<cr>"

  for _, lhs in ipairs({ "q", "<esc>", "<c-[>", "<c-]>" }) do
    bm.n(lhs, rhs)
  end
end
