---那天她说想吃巧克力
---
---design choices, features, limits
---* keyword/fixedstr only, with boundary
---* finite number of colors
---* match scope: incremental
---* per-buffer state
---* highlights showing in all windows
---  * extmark vs matchadd*
---* no jump support. use a motion plugin instead
---* no auto-update/delete. highlights may become inaccurate while buffer changes.
---  * nvim_buf_attach+nvim_set_decoration_provider make the impl complex

local M = {}

local bags = require("infra.bags")
local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("chocolate.dove", "info")
local ni = require("infra.ni")
local nuts = require("infra.nuts")

local facts = require("chocolate.facts")
local shared = require("chocolate.shared")

---@class chocolate.dove.Bag
---@field palette chocolate.Palette
---@field ns    table<string,integer> {keyword:namespace}
---@field color table<string,integer> {keyword:color}
---@field ng    table<string,integer> {keyword:generation}

local Bag = bags.wraps("chocolate.dove", function() end)

function M.bag(bufnr) return Bag.get(bufnr) end

---@param bufnr integer
---@param keyword? string
function M.clear(bufnr, keyword)
  ---@type chocolate.dove.Bag?
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
  else
    if bag.ns[keyword] == nil then return end
    ni.buf_clear_namespace(bufnr, bag.ns[keyword], 0, -1)
    bag.palette:free(bag.color[keyword])
    bag.ns[keyword] = nil
    bag.color[keyword] = nil
    bag.ng[keyword] = nil
  end
end

---@param winid integer
---@param keyword string
function M.highlight(winid, keyword)
  local bufnr = ni.win_get_buf(winid)
  ---@type chocolate.dove.Bag
  local bag = Bag.get(bufnr) or Bag.new(bufnr, { palette = shared.Palette(#facts.palette), ns = {}, color = {}, ng = {} })

  if bag.ns[keyword] == nil then
    local color = bag.palette:allocate()
    if color == nil then return jelly.info("ran out of color") end

    bag.ns[keyword] = ni.create_namespace(string.format("chocolate.snicker.%s.%s", bufnr, keyword))
    bag.color[keyword] = color
    bag.ng[keyword] = 0
  end

  --clear prev set xmarks
  ni.buf_clear_namespace(bufnr, assert(bag.ns[keyword]), 0, -1)

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
  end

  do --highlight all occurences at first time
    local poses = {}
    local regex = shared.Regex(keyword)
    for lnum = bound_low, bound_high do
      for start, stop in regex:iter_line(bufnr, lnum) do
        table.insert(poses, { lnum, start, stop })
      end
    end
    --not abort on #poses<2 anymore, i think it's still worth to highlight only one occurence

    local higroup = assert(facts.higroups[bag.color[keyword]])
    local ns = bag.ns[keyword]
    for _, pos in ipairs(poses) do
      shared.hi_occurence(bufnr, ns, higroup, unpack(pos))
    end
  end
end

return M
