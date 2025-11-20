local dictlib = require("infra.dictlib")
local ni = require("infra.ni")

---@class infra.BufTickRegulator
---@field private ticks {[integer]: integer} @{bufnr: changedtick}
local Regulator = {}
do
  Regulator.__index = Regulator

  ---@param bufnr integer
  ---@return boolean
  function Regulator:throttled(bufnr)
    --concern: regard of current undo block, yet there is no api
    local last = self.ticks[bufnr] or 0
    local now = ni.buf_get_changedtick(bufnr)
    return last == now
  end

  ---@param bufnr integer
  function Regulator:update(bufnr) self.ticks[bufnr] = ni.buf_get_changedtick(bufnr) end
end

return function(cap) return setmetatable({ ticks = dictlib.CappedDict(cap) }, Regulator) end
