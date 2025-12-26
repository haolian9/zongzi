-- inspired by vim-repeat

local M = {}

local feedkeys = require("infra.feedkeys")
local mi = require("infra.mi")
local ni = require("infra.ni")

do
  local state = {
    ---@type {[integer]: fun()}
    redo = {},
    ---@type {[integer]: integer}
    tick = {},
  }

  ---NB: call this after your changes are done due to &changedtick
  ---@param bufnr integer
  ---@param redo fun()
  function M.remember_redo(bufnr, redo)
    bufnr = mi.resolve_bufnr_param(bufnr)
    state.tick[bufnr] = ni.buf_get_changedtick(bufnr)
    state.redo[bufnr] = redo
  end

  --should be only used in normal mode
  ---@param bufnr integer
  function M.rhs_dot(bufnr)
    bufnr = mi.resolve_bufnr_param(bufnr)
    local last_tick = state.tick[bufnr]
    if last_tick == nil then return feedkeys.codes(".", "n") end

    local held_tick = ni.buf_get_changedtick(bufnr)
    if held_tick ~= last_tick then
      state.tick[bufnr] = nil
      state.redo[bufnr] = nil
      return feedkeys.codes(".", "n")
    end

    assert(state.redo[bufnr])()
  end
end

do
  --to repeat f/t/F/T, using `,` and `;`
  --global, no buffer-local

  local state = {
    ---@type fun()
    next = nil,
    ---@type fun()
    prev = nil,
  }

  ---@param next fun()
  ---@param prev fun()
  function M.remember_charsearch(next, prev)
    vim.fn.setcharsearch({ char = "" })
    state.next = next
    state.prev = prev
  end

  local function comma()
    if state.prev == nil then return feedkeys.codes(",", "n") end

    if vim.fn.getcharsearch().char ~= "" then
      state.prev = nil
      return feedkeys.codes(",", "n")
    end

    if state.prev then return state.prev() end
  end

  --should be only used in normal mode
  function M.rhs_comma()
    for _ = 1, vim.v.count1 do
      comma()
    end
  end

  local function semicolon()
    if state.next == nil then return feedkeys.codes(";", "n") end

    if vim.fn.getcharsearch().char ~= "" then
      state.next = nil
      return feedkeys.codes(";", "n")
    end

    if state.next then return state.next() end
  end

  --should be only used in normal mode
  function M.rhs_semicolon()
    for _ = 1, vim.v.count1 do
      semicolon()
    end
  end
end

do
  --to repeat [c,[l,[b,[a,[w,[e,[k, using `(` and `)`
  --global, no buffer-local

  local state = {
    ---@type fun()
    next = nil,
    ---@type fun()
    prev = nil,
  }

  ---@param next fun()
  ---@param prev fun()
  function M.remember_paren(next, prev)
    state.next = next
    state.prev = prev
  end

  --should be only used in normal mode
  function M.rhs_parenleft()
    for _ = 1, vim.v.count1 do
      if state.prev then state.prev() end
    end
  end

  --should be only used in normal mode
  function M.rhs_parenright()
    for _ = 1, vim.v.count1 do
      if state.next then state.next() end
    end
  end
end

return M
