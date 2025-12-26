local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("sting.rhs")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

local facts = require("sting.facts")

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
    wincursor.g1(
      0,
      pickle.lnum, --.lnum is 1-based
      math.max(0, pickle.col - 1) --.col is exclusive it seems
    )
  end
end

do
  local preview_winid = -1
  local preview_aug = augroups.Augroup("sting://preview")

  local function close_preview_win()
    if not ni.win_is_valid(preview_winid) then return end
    ni.win_close(preview_winid, false)
  end

  ---@param qf_winid integer
  ---@param ctx_lines integer
  ---@return table
  local function resolve_preview_winpos(qf_winid, ctx_lines)
    return {
      relative = "win",
      anchor = "SW",
      row = 0,
      col = 0,
      height = (2 * ctx_lines) + 1,
      width = ni.win_get_width(qf_winid) - 1,
      border = "single",
    }
  end

  function M.preview()
    close_preview_win()

    local bufnr, lnum, col
    do
      local pickle = resolve_current_pickle()
      if pickle == nil then return end
      bufnr, lnum, col = pickle.bufnr, pickle.lnum, pickle.col
      lnum = lnum - 1
      assert(bufnr and lnum and col)
    end

    if not ni.buf_is_loaded(bufnr) then
      local bo = prefer.buf(bufnr)
      local bh, ml = bo.bufhidden, bo.modeline
      bo.bufhidden, bo.modeline = "unload", false
      ni.create_autocmd("BufUnload", {
        buffer = bufnr,
        once = true,
        callback = function()
          bo.bufhidden, bo.modeline = bh, ml
        end,
      })
    end

    do
      --by default no syn/ft/ts/lsp ...
      local winopts = { noautocmd = true, focusable = false }
      local qf_winid = ni.get_current_win()
      dictlib.merge(winopts, resolve_preview_winpos(qf_winid, 3))

      preview_winid = rifts.open.win(bufnr, false, winopts)
      ni.win_set_hl_ns(preview_winid, rifts.ns)

      --put cursor at center
      wincursor.go(preview_winid, lnum, col)
      wincursor.zz(preview_winid)

      --highlight the main line
      vim.fn.matchaddpos(facts.preview_hi, { lnum + 1 }, nil, -1, { window = preview_winid })
    end

    preview_aug:once("CursorMoved", { nested = true, callback = close_preview_win })
  end

  function M.open()
    close_preview_win()
    feedkeys("<cr>", "n")
  end
end

return M
