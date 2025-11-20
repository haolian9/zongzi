local uv = vim.uv

---@class infra.Debounce
---@field private timer uv_timer_t
---@field private window integer @time window in milliseconds
local Impl = {}
Impl.__index = Impl

---@param action fun() @which will run in vim.schedule()
function Impl:start_soon(action)
  self.timer:stop()
  self.timer:start(self.window, 0, vim.schedule_wrap(action))
end

function Impl:close()
  self.timer:stop()
  self.timer:close()
end

---@param window integer @time window in milliseconds
---@return infra.Debounce
return function(window)
  local timer = uv.new_timer()
  return setmetatable({ timer = timer, window = window }, Impl)
end

