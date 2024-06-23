local M = {}

local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("sting.rhs")
local ni = require("infra.ni")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

do
  ---@return nil|sting.Pickle
  local function resolve_current_pickle()
    local winid = ni.get_current_win()
    local wininfo = vim.fn.getwininfo(winid)[1]
    local expect_idx = wincursor.row(winid)
    ---must check loclist first, as .quickfix=1 in both location and quickfix window
    if wininfo.loclist == 1 then
      local held_idx = vim.fn.getloclist(0, { idx = 0 }).idx
      if held_idx < 1 then return jelly.debug("no lines in current quickfix list") end
      if held_idx ~= expect_idx then
        vim.fn.setloclist(winid, {}, "a", { idx = expect_idx })
        held_idx = expect_idx
      end
      ---@type sting.Pickle
      return vim.fn.getloclist(0, { idx = held_idx, items = 0 }).items[1]
    elseif wininfo.quickfix == 1 then
      local held_idx = vim.fn.getqflist({ idx = 0 }).idx
      if held_idx < 1 then return jelly.debug("no lines in current location list") end
      if held_idx ~= expect_idx then
        vim.fn.setqflist({}, "a", { idx = expect_idx })
        held_idx = expect_idx
      end
      ---@type sting.Pickle
      return vim.fn.getqflist({ idx = held_idx, items = 0 }).items[1]
    end

    return jelly.fatal("RuntimeError", "supposed to be in a quickfix/location window: winid=%d, wininfo=%s", winid, wininfo)
  end

  ---@param side infra.winsplit.Side
  function M.split(side)
    local pickle = resolve_current_pickle()
    if pickle == nil then return end
    assert(pickle.bufnr and pickle.lnum and pickle.col)

    do
      ex("wincmd", "p")
      winsplit(side, pickle.bufnr)
      wincursor.g1(0, pickle.lnum, pickle.col - 1) --pickle.lnum is 1-based, and .col is exclusive it seems
    end
  end
end

return M
