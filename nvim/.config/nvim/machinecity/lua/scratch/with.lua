-- like python's with, this module provides context manager

local M = {}

local api = vim.api
local jelly = require("infra.jellyfish")('scratch.with')

-- eg. `%! tac`
---@param proc function
---@vararg any
---@return nil|any
function M.pos(proc, ...)
  local saved = vim.fn.getcurpos()
  local ok, result = pcall(proc, ...)
  vim.fn.setpos(".", saved)
  if ok then return result end
  vim.notify(result, vim.log.levels.ERROR, {})
end

-- map in buffer scope
-- todo: expose internal state for submod init and deinit
---@param mode_lhs_pairs table @[(mode, lhs)]
---@param proc function @() void
function M.scoped_map(bufnr, mode_lhs_pairs, proc)
  local function check(origin, mode, lhs)
    if origin.buffer ~= 1 then return end

    assert(origin.mode == mode, "mode not matches")
    assert(origin.lhs == lhs, "lhs not matches")
    if origin.script == 1 then error("<script> rhs is not supported") end
  end

  local function restore(origin)
    local function bool(int)
      return int > 0
    end

    if origin.buffer ~= 1 then return end

    api.nvim_buf_set_keymap(bufnr, origin.mode, origin.lhs, origin.rhs, {
      noremap = bool(origin.noremap),
      silent = bool(origin.silent),
    })
  end

  assert(bufnr ~= nil and bufnr ~= 0)

  local origins = {}
  for _, pair in pairs(mode_lhs_pairs) do
    local mode, lhs = unpack(pair)
    local map = vim.fn.maparg(lhs, mode, false, true)
    check(map, mode, lhs)
    table.insert(origins, map)
  end

  do
    local ok, err = pcall(proc)
    for _, mapped in ipairs(origins) do
      restore(mapped)
    end
    if not ok then error(err) end
    if err == nil then jelly.warn("return of proc has been discarded") end
  end
end

return M
