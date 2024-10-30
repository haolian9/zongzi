local M = {}

local jelly = require("infra.jellyfish")("ido.anchors", "info")
local ni = require("infra.ni")

local facts = require("ido.facts")

---@class ido.XmarkPos
---@field start_lnum integer
---@field start_col integer
---@field stop_lnum integer
---@field stop_col integer

---@param bufnr integer
---@param xmid integer
---@return ido.XmarkPos?
function M.pos(bufnr, xmid)
  local xm = ni.buf_get_extmark_by_id(bufnr, facts.anchor_ns, xmid, { details = true })

  if #xm == 0 then return end
  ---the anchor can be 0-range

  return { start_lnum = xm[1], start_col = xm[2], stop_lnum = xm[3].end_row, stop_col = xm[3].end_col }
end

---@param bufnr integer
---@param id_or_pos integer|ido.XmarkPos
---@return string[]|nil
function M.text(bufnr, id_or_pos)
  local pos
  if type(id_or_pos) == "number" then
    pos = M.pos(bufnr, id_or_pos)
    if pos == nil then return end
  else
    pos = id_or_pos
  end

  ---as the extmark.invalidate=true is not being used, the pos could be invalid
  local ok, text = pcall(ni.buf_get_text, bufnr, pos.start_lnum, pos.start_col, pos.stop_lnum, pos.stop_col, {})
  if ok then return text end
  if text == "Index out of bounds" then return end
  if text == "start_col must be less than end_col" then return end
  jelly.fatal("unreachable", "buf=%d; pos=%s; err=%s", bufnr, pos, text)
end

---@param bufnr integer
---@param origin ido.Origin
---@param group string
---@param expandable boolean
function M.set(bufnr, origin, group, expandable)
  local opts = {
    end_row = origin.lnum,
    end_col = origin.stop_col,
    hl_group = group,
    hl_mode = "replace",
    ---intended to not use {.invalidate, .undo_restore}
  }
  if expandable then
    opts.right_gravity = false
    opts.end_right_gravity = true
  else
    opts.right_gravity = true
    opts.end_right_gravity = false
  end

  return ni.buf_set_extmark(bufnr, facts.anchor_ns, origin.lnum, origin.start_col, opts)
end

---@param bufnr integer
---@param xmid integer
function M.del(bufnr, xmid) ni.buf_del_extmark(bufnr, facts.anchor_ns, xmid) end

return M
