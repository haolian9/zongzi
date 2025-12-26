---Bag stores 'Buffer variables', like `b:` but for lua only
---
---designs
---* term namespace: stands for a module/plugin, should be unique
---* firstly, M.new(bufnr,namespace,free)
---* when BufWipeout, all related buffer .bag gets deleted, .free() gets called
local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")

---@alias infra.bags.free fun(bufnr:integer,bag:table)

---{bufnr:{namespace:{bag,free}}}
---@type table<integer,table<string,{bag:table,free:infra.bags.free}>>
local store = {}

function M.init()
  M.init = nil

  local aug = augroups.Augroup("infra://bags")
  aug:repeats("BufWipeout", {
    callback = function(args)
      local bufnr = args.buf
      if store[bufnr] == nil then return end
      for _, v in pairs(store[bufnr]) do
        v.free(bufnr, v.bag)
      end
      store[bufnr] = nil
    end,
  })
end

---@param bufnr integer
---@param namespace string
---@param free infra.bags.free
---@param bag? table
---@return table bag
function M.new(bufnr, namespace, free, bag)
  bag = bag or {}
  assert(type(bag) == "table")
  if store[bufnr] == nil then store[bufnr] = {} end
  assert(store[bufnr][namespace] == nil, "cant re-new bag")
  store[bufnr][namespace] = { bag = bag, free = free }
  return store[bufnr][namespace].bag
end

---@param bufnr integer
---@param namespace string
---@return table? bag
function M.get(bufnr, namespace) return dictlib.get(store, bufnr, namespace, "bag") end

---@class infra.Bag
---@field new fun(bufnr:integer,bag:table):table
---@field get fun(bufnr:integer):table?

---@param namespace string
---@param free infra.bags.free
---@return infra.Bag
function M.wraps(namespace, free)
  return {
    new = function(bufnr, bag) return M.new(bufnr, namespace, free, bag) end,
    get = function(bufnr) return M.get(bufnr, namespace) end,
  }
end

return M
