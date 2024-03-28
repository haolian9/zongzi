-- inspired by vim-repeat

local M = {}

local api = vim.api
local ex = require("infra.ex")

local state = {
  ---@type table<number, fun()>
  callback = {},
  ---@type table<number, fun()>
  tick = {},
}

function M.remember(bufnr, callback)
  state.tick[bufnr] = api.nvim_buf_get_changedtick(bufnr)
  state.callback[bufnr] = callback
end

local function vanilla_dot() ex("normal", ".") end

function M.dot(bufnr)
  local held_tick = api.nvim_buf_get_changedtick(bufnr)
  local repeatfn = state.callback[bufnr]
  local last_tick = state.tick[bufnr]
  if held_tick ~= last_tick then return vanilla_dot() end
  assert(repeatfn, "unreachable")
  repeatfn()
end

return M
