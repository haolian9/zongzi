---a regulator for buffers based on changedtick

local dictlib = require("infra.dictlib")

local api = vim.api

---@class infra.Regulator
---@field private ticks {[integer]: integer} @{bufnr: changedtick}
local Regulator = {}
do
  Regulator.__index = Regulator

  ---@param bufnr integer
  ---@return boolean
  function Regulator:throttled(bufnr)
    --todo: take the current undo block into account
    local last = self.ticks[bufnr] or 0
    local now = api.nvim_buf_get_changedtick(bufnr)
    return last == now
  end

  ---@param bufnr integer
  function Regulator:update(bufnr) self.ticks[bufnr] = api.nvim_buf_get_changedtick(bufnr) end
end

return function(cap)
  return setmetatable({ ticks = dictlib.CappedDict(cap) }, Regulator)
end
