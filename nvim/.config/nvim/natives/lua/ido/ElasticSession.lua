local augroups = require("infra.augroups")
local Debounce = require("infra.Debounce")
local feedkeys = require("infra.feedkeys")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("ido.ElasticSession", "info")
local ni = require("infra.ni")
local strlib = require("infra.strlib")
local VimRegex = require("infra.VimRegex")
local wincursor = require("infra.wincursor")

local anchors = require("ido.anchors")

---@class ido.Origin
---@field lnum integer
---@field start_col integer
---@field stop_col integer

---truth_{idx,xmid} -> truth of source; anchor
---
---@class ido.ElasticSession
---
---@field status 'created'|'active'|'inactive'
---
---@field bufnr integer
---@field title string
---
---@field origins ido.Origin[]
---@field truth_idx integer
---
---@field xmids integer[]
---@field truth_xmid integer @==xmids[truth_idx]
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
      self.xmids[i] = anchors.set(self.bufnr, origin, group, true)
    end
    self.truth_xmid = self.xmids[self.truth_idx]
  end

  self.aug = augroups.BufAugroup(self.bufnr, "ido", true)
  self.debounce = Debounce(125)

  do --sync mechanism
    ---known facts:
    ---* buf_set_text wont trigger TextChanged/I in insert/normal mode
    ---* undo also triggers TextChanged and buf_set_text here creates undo blocks, this leads infinite undo
    ---
    ---design choices
    ---* only sync changes from truth_xm
    ---* allow change other xms, but no syncing
    ---
    ---workaround for undo/redo
    ---* compare last_text and truth_text to avoid replicate triggering

    --workaround of undo/redo
    ---@type string[]
    local last_text = assert(anchors.text(self.bufnr, self.truth_xmid))

    local function on_change()
      local truth_text = anchors.text(self.bufnr, self.truth_xmid)
      if truth_text == nil then
        jelly.info("anchor#0 has gone")
        self:deactivate()
        return true
      end

      if itertools.equals(truth_text, last_text) then return jelly.debug("no changes") end

      self.debounce:start_soon(function()
        last_text = truth_text

        for i = 1, #self.xmids do
          if i == self.truth_idx then goto continue end
          local pos = anchors.pos(self.bufnr, self.xmids[i])
          if pos == nil then goto continue end
          ---as the extmark.invalidate=true is not being used, the pos could be invalid
          pcall(ni.buf_set_text, self.bufnr, pos.start_lnum, pos.start_col, pos.stop_lnum, pos.stop_col, truth_text)
          ::continue::
        end
        ---intended to do nothing on undo block, IMO this is the most nature behavior
      end)
    end
    self.aug:repeats({ "TextChanged", "TextChangedI" }, { callback = on_change })
  end

  do --initial cursor
    local pos = assert(anchors.pos(self.bufnr, self.truth_xmid))
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
  for _, xmid in ipairs(self.xmids) do
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
---@return ido.ElasticSession?
return function(winid, cursor, start_lnum, stop_lnum, pattern)
  local bufnr = ni.win_get_buf(winid)

  local origins = {} ---@type ido.Origin[]
  do
    local regex = VimRegex(pattern)
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
    if #origins < 2 then return jelly.warn("no other matches") end
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

  local title = string.format("buf#%d (%s, ) '%s'", bufnr, start_lnum, stop_lnum, pattern)

  --stylua: ignore
  return setmetatable({
    status = "created",
    bufnr = bufnr, title = title,
    origins = origins, truth_idx = truth_idx,
    xmids = {}, truth_xmid = nil,
  }, Session)
end
