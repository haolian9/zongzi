---design choices, impl
---* xmark layout: [left][core][right]
---* core is immutable
---* left and right are mutable
---* changing core will deactivate the session

local augroups = require("infra.augroups")
local Debounce = require("infra.Debounce")
local feedkeys = require("infra.feedkeys")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("ido.CoredSession", "info")
local ni = require("infra.ni")
local strlib = require("infra.strlib")
local VimRegex = require("infra.VimRegex")
local wincursor = require("infra.wincursor")

local anchors = require("ido.anchors")

---truth_{idx,xmid} -> truth of source; anchor
---
---@class ido.CoredSession
---
---@field status 'created'|'active'|'inactive'
---
---@field bufnr integer
---@field title string
---
---@field origins ido.Origin[]
---@field truth_idx integer
---
---@field core_xmids integer[]
---@field left_xmids integer[]
---@field right_xmids integer[]
---@field truth_xmid integer @==core_xmids[truth_idx]
---
---@field aug infra.BufAugroup
---@field debounce infra.Debounce
local Session = {}
Session.__index = Session

function Session:activate()
  assert(self.status == "created")

  do --place anchors
    for i = 1, #self.origins do
      local origin = self.origins[i]
      local group = i == self.truth_idx and "IdoTruth" or "IdoReplica"
      self.core_xmids[i] = anchors.set(self.bufnr, origin, group, false)
      self.left_xmids[i] = anchors.set(self.bufnr, { lnum = origin.lnum, start_col = origin.start_col, stop_col = origin.start_col }, group, true)
      self.right_xmids[i] = anchors.set(self.bufnr, { lnum = origin.lnum, start_col = origin.stop_col, stop_col = origin.stop_col }, group, true)
    end
    self.truth_xmid = self.core_xmids[self.truth_idx]
  end

  self.aug = augroups.BufAugroup(self.bufnr, "ido", true)
  self.debounce = Debounce(125)

  do --sync mechanism
    local core_truth = assert(anchors.text(self.bufnr, self.core_xmids[self.truth_idx]))

    --workaround of undo/redo
    ---@type string[], string[]
    local last_left, last_right = {}, {}

    ---@param xmids integer[]
    ---@param truth_text string[]
    local function sync(xmids, truth_text)
      for i = 1, #xmids do
        if i == self.truth_idx then goto continue end
        local pos = anchors.pos(self.bufnr, xmids[i])
        if pos == nil then goto continue end
        ---as the extmark.invalidate=true is not being used, the pos could be invalid
        pcall(ni.buf_set_text, self.bufnr, pos.start_lnum, pos.start_col, pos.stop_lnum, pos.stop_col, truth_text)
        ::continue::
      end
      ---intended to do nothing on undo block, IMO this is the most nature behavior
    end

    local function on_change()
      do --ensure the truth_core still exists
        local text = anchors.text(self.bufnr, self.core_xmids[self.truth_idx])
        if text == nil or not itertools.equals(text, core_truth) then
          jelly.info("deactivated: truth_core has been changed")
          self:deactivate()
          return true
        end
      end

      local left_sync, right_sync
      do
        local left_truth = anchors.text(self.bufnr, self.left_xmids[self.truth_idx])
        assert(left_truth ~= nil)
        local right_truth = anchors.text(self.bufnr, self.right_xmids[self.truth_idx])
        assert(right_truth ~= nil)

        if not itertools.equals(last_left, left_truth) then --
          function left_sync()
            last_left = left_truth
            sync(self.left_xmids, left_truth)
          end
        end
        if not itertools.equals(last_right, right_truth) then --
          function right_sync()
            last_right = right_truth
            sync(self.right_xmids, right_truth)
          end
        end

        if left_sync == nil and right_sync == nil then return jelly.debug("no changes to sync") end
      end

      self.debounce:start_soon(function()
        if left_sync then left_sync() end
        if right_sync then right_sync() end
      end)
    end
    self.aug:repeats({ "TextChanged", "TextChangedI" }, { callback = on_change })
  end

  do --initial cursor
    local xmid = assert(self.core_xmids[self.truth_idx])
    local pos = assert(anchors.pos(self.bufnr, xmid))
    assert(pos.stop_col > 0)
    wincursor.go(0, pos.stop_lnum, pos.stop_col - 1)
    feedkeys("a", "n")
  end

  self.status = "active"
end

function Session:deactivate()
  if self.status == "created" then goto beinactive end
  if self.status == "inactive" then return end

  self.aug:unlink()
  self.debounce:close()
  for xmid in itertools.chained(self.core_xmids, self.left_xmids, self.right_xmids) do
    anchors.del(self.bufnr, xmid)
  end

  ::beinactive::
  self.status = "inactive"
end

---@param winid integer
---@param cursor infra.wincursor.Position
---@param pattern string
---@param start_lnum integer @0-based; inclusive
---@param stop_lnum integer @0-based; exclusive
---@return ido.CoredSession?
return function(winid, cursor, start_lnum, stop_lnum, pattern)
  local bufnr = ni.win_get_buf(winid)

  local origins = {} ---@type ido.Origin[]
  do
    local regex = assert(VimRegex(pattern))
    for lnum = start_lnum, stop_lnum - 1 do
      for start_col, stop_col in regex:iter_line(bufnr, lnum) do
        local prev = origins[#origins]
        if prev and prev.lnum == lnum and prev.stop_col == start_col then --
          return jelly.fatal("RuntimeError", "found two contiguous origins: (%d,%d), (%d,%d)", prev.start_col, prev.stop_col, start_col, stop_col)
        end
        table.insert(origins, { lnum = lnum, start_col = start_col, stop_col = stop_col })
        if strlib.startswith(pattern, "^") or strlib.endswith(pattern, "$") then break end
      end
    end
    if #origins < 2 then return jelly.warn("no other matches; pattern: %s", pattern) end
  end

  local truth_idx
  do
    local min_dis
    for i = 1, #origins do
      local origin = origins[i]
      if origin.lnum ~= cursor.lnum then goto continue end
      local dis = math.min(math.abs(origin.start_col - cursor.col), math.abs(origin.stop_col - cursor.col))
      if min_dis == nil or dis < min_dis then
        min_dis = dis
        truth_idx = i
      end
      ::continue::
    end
    if truth_idx == nil then truth_idx = 1 end
  end

  local title = string.format("buf#%d (%s, %s) '%s'", bufnr, start_lnum, stop_lnum, pattern)

  --stylua: ignore
  return setmetatable({
    status = "created",
    bufnr = bufnr, title = title,
    origins = origins, truth_idx = truth_idx,
    core_xmids = {}, left_xmids = {}, right_xmids = {},
  }, Session)
end
