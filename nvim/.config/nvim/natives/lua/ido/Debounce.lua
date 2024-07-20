local uv = vim.uv

---@class ido.Debounce
---@field timer uv_timer_t
---@field delay integer @in milliseconds
local Impl = {}
Impl.__index = Impl

function Impl:start_soon(logic)
  self.timer:stop()
  self.timer:start(self.delay, 0, vim.schedule_wrap(logic))
end

function Impl:close()
  self.timer:stop()
  self.timer:close()
end

---@param delay integer @in milliseconds
---@return ido.Debounce
return function(delay)
  local timer = uv.new_timer()
  return setmetatable({ timer = timer, delay = delay }, Impl)
end
