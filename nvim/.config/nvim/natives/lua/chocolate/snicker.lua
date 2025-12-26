local M = {}

local bags = require("infra.bags")
local buflines = require("infra.buflines")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("chocolate.snicker", "info")
local logging = require("infra.logging")
local ni = require("infra.ni")
local nuts = require("infra.nuts")

local facts = require("chocolate.facts")
local shared = require("chocolate.shared")

local log = logging.newlogger("chocolate.snicker", "info")

local bound_ns = ni.create_namespace("chocolate.snicker.bounds")

---@param set table
---@return boolean
local function zeroset(set) return select(1, next(set)) == nil end

---@param bufnr integer
---@param lnum integer 0-based
---@return integer xmid
local function hi_bound(bufnr, lnum)
  return ni.buf_set_extmark(bufnr, bound_ns, lnum, 0, {
    end_row = lnum,
    end_col = 0,
    right_gravity = false,
    end_right_gravity = false,
    invalidate = true,
    undo_restore = true,
  })
end

---@param bufnr integer
---@param xmid integer
---@return integer? lnum
local function get_bound_lnum(bufnr, xmid)
  local info = ni.buf_get_extmark_by_id(bufnr, bound_ns, xmid, { details = true })
  if info[3].invalid then return end
  return info[1]
end

local Keeper
do
  ---@class chocolate.snicker.Keeper
  ---@field status 'init'|'start'|'pause'|'deinit'
  ---@field bufnr  integer
  ---@field bag    chocolate.snicker.Bag
  ---@field timer  uv_timer_t
  ---@field dels   table<integer,true>
  ---@field adds   table<integer,true>
  local Impl = {}
  Impl.__index = Impl

  ---@private
  function Impl:on_lines(start, stop, stop_now)
    assert(self.status == "start", self.status)
    if zeroset(self.bag.ns) then return end

    log.debug("changes: %s,%s %s,%s", start, stop, start, stop_now)

    for lnum = start, stop_now do
      self.dels[lnum] = true
      self.adds[lnum] = true
    end
  end

  ---@private
  function Impl:on_tick()
    if self.status == "deinit" then return end
    if self.status == "pause" then return end
    assert(self.status == "start", self.status)
    if zeroset(self.bag.ns) then return end

    if zeroset(self.dels) and zeroset(self.dels) then return end
    local dels, adds = self.dels, self.adds
    self.dels, self.adds = {}, {}

    if not zeroset(dels) then --clear xmarks
      for _, ns in pairs(self.bag.ns) do
        ---this should be efficient as there wont be too many (100) xmarks
        local xmids = ni.buf_get_extmarks(self.bufnr, ns, 0, -1, {})
        for _, info in ipairs(xmids) do
          local xmid, lnum = unpack(info)
          if dels[lnum] then ni.buf_del_extmark(self.bufnr, ns, xmid) end
        end
      end
    end

    if not zeroset(adds) then --add xmarks
      local bounds = {} ---@type table<string,{low:integer,high:integer}>
      for keyword, xmarks in pairs(self.bag.bounds) do
        local low = get_bound_lnum(self.bufnr, xmarks.low)
        local high = get_bound_lnum(self.bufnr, xmarks.high)
        if low and high then
          bounds[keyword] = { low = low, high = high }
        else
          jelly.info("bounds of keyword=%s are lost.", keyword)
        end
      end
      log.debug("bounds: %s", bounds)

      for lnum in pairs(adds) do
        for keyword, ns in pairs(self.bag.ns) do
          local b = bounds[keyword]
          if b == nil then goto continue end
          if lnum < b.low then goto continue end
          if lnum > b.high then goto continue end
          local regex = self.bag.regex[keyword]
          local higroup = facts.higroups[self.bag.color[keyword]]
          for start, stop in regex:iter_line(self.bufnr, lnum) do
            shared.hi_occurence(self.bufnr, ns, higroup, lnum, start, stop)
          end
          ::continue::
        end
      end
    end
  end

  function Impl:start()
    if self.status == "deinit" then error("keeper was deinited") end
    if self.status == "start" then return end
    assert(self.status == "init" or self.status == "pause", self.status)
    self.status = "start"

    assert(ni.buf_attach(self.bufnr, false, {
      on_lines = function(_, _, _, start, stop, stop_now)
        if self.status == "deinit" then return true end
        if self.status == "pause" then return true end
        return self:on_lines(start, stop, stop_now)
      end,
      on_detach = function() self:deinit() end,
    }))
    self.timer:start(0, 1000, vim.schedule_wrap(function() return self:on_tick() end))

    jelly.debug("keeper: started")
  end

  function Impl:pause()
    if self.status == "deinit" then error("keeper was deinited") end
    if self.status == "pause" then return end
    assert(self.status == "start", self.status)
    self.status = "pause"
    self.timer:stop()
    jelly.debug("keeper: paused")
  end

  function Impl:deinit()
    if self.status == "deinit" then return end
    self.status = "deinit"
    self.timer:stop()
    self.timer:close()
    jelly.debug("keeper: deinited")
  end

  ---@param bufnr integer
  ---@param bag chocolate.snicker.Bag
  ---@return chocolate.snicker.Keeper
  function Keeper(bufnr, bag)
    return setmetatable({
      status = "init",
      bufnr = bufnr,
      bag = bag,
      timer = iuv.new_timer(),
      dels = {},
      adds = {},
    }, Impl)
  end
end

---@class chocolate.snicker.Bounds
---@field low integer low-xmid
---@field high integer high-xmid

---@class chocolate.snicker.Bag
---
---@field palette chocolate.Palette
---@field keeper  chocolate.snicker.Keeper
---@field ns      table<string,integer> {keyword:namespace}
---@field color   table<string,integer> {keyword:color}
---@field ng      table<string,integer> {keyword:generation}
---@field regex   table<string,infra.VimRegex> {keyword:regex}
---@field bounds  table<string,chocolate.snicker.Bounds> {keyword:bounds}

local Bag = bags.wraps("chocolate.snicker", function(_, bag)
  ---@cast bag chocolate.snicker.Bag
  bag.keeper:deinit()
end)

function M.bag(bufnr) return Bag.get(bufnr) end

---@param bufnr integer
---@param keyword? string
function M.clear(bufnr, keyword)
  ---@type chocolate.snicker.Bag?
  local bag = Bag.get(bufnr)
  if bag == nil then return end
  if keyword == nil then
    for _, ns in pairs(bag.ns) do
      ni.buf_clear_namespace(bufnr, ns, 0, -1)
    end
    bag.palette:reset()
    bag.ns = {}
    bag.color = {}
    bag.ng = {}
    bag.regex = {}
    bag.bounds = {}
  else
    if bag.ns[keyword] == nil then return end
    ni.buf_clear_namespace(bufnr, assert(bag.ns[keyword]), 0, -1)
    bag.palette:free(assert(bag.color[keyword]))
    bag.ns[keyword] = nil
    bag.color[keyword] = nil
    bag.ng[keyword] = nil
    bag.regex[keyword] = nil
    bag.bounds[keyword] = nil
  end
  if zeroset(bag.ns) then bag.keeper:pause() end
end

---@param winid integer
---@param keyword string
function M.highlight(winid, keyword)
  local bufnr = ni.win_get_buf(winid)
  local bag = Bag.get(bufnr) ---@type chocolate.snicker.Bag?
  if bag == nil then
    bag = Bag.new(bufnr, { ns = {}, color = {}, ng = {}, regex = {}, bounds = {} })
    bag.palette = shared.Palette(#facts.palette)
    bag.keeper = Keeper(bufnr, bag)
  end

  if bag.ns[keyword] == nil then
    local color = bag.palette:allocate()
    if color == nil then return jelly.info("ran out of color") end

    bag.color[keyword] = color
    bag.ns[keyword] = ni.create_namespace(string.format("chocolate.snicker.%s.%s", bufnr, keyword))
    bag.ng[keyword] = 0
    bag.regex[keyword] = shared.Regex(keyword)
    bag.bounds[keyword] = nil
  end

  --todo: do nothing when ng changes not
  do --clear prev set xmarks
    for _, bound_xmid in pairs(bag.bounds[keyword] or {}) do
      ni.buf_del_extmark(bufnr, bound_ns, bound_xmid)
    end
    ni.buf_clear_namespace(bufnr, assert(bag.ns[keyword]), 0, -1)
  end

  local bound_low, bound_high --both are 0-based and inclusive
  do
    local ng = assert(bag.ng[keyword]) + 1
    local node = shared.find_stop_node(winid, ng)
    if node == nil then
      bound_low, bound_high = 0, buflines.high(bufnr)
    else
      local start, _, stop = nuts.node_range(node)
      bound_low, bound_high = start, stop
    end

    if node then bag.ng[keyword] = ng end
    bag.bounds[keyword] = { low = hi_bound(bufnr, bound_low), high = hi_bound(bufnr, bound_high) }
  end

  do --highlight all occurences at first time
    local poses = {} ---@type integer[][]
    local regex = bag.regex[keyword]
    for lnum = bound_low, bound_high do
      for start_col, stop_col in regex:iter_line(bufnr, lnum) do
        table.insert(poses, { lnum, start_col, stop_col })
      end
    end

    local higroup = assert(facts.higroups[bag.color[keyword]])
    local ns = bag.ns[keyword]
    for _, pos in ipairs(poses) do
      shared.hi_occurence(bufnr, ns, higroup, unpack(pos))
    end
  end

  bag.keeper:start()
end

return M
