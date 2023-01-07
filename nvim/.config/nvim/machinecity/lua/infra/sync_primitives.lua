local M = {}

local defaults = {
  -- unit: ms
  interval = 100,
  -- unit: ms
  timeout = 3000,
}

local function wait(ms_timeout, predicate, check_interval)
  -- error("there is no real non-blocking wait in nvim")

  local interval = check_interval or defaults.interval
  -- todo: need to yield explicitly?
  -- todo: vim.schedule instead of vim.wait to gain more efficient
  local finished, extra = vim.wait(ms_timeout, predicate, interval)
  if extra == -2 then error("canceled by user") end
  return finished
end

-- api design is stolen from trio.Semaphore
-- no re-entrance
---@param initial_value number
---@param max_value number|nil @default initial_value
M.create_semaphore = function(initial_value, max_value)
  assert(initial_value >= 0)
  max_value = max_value or initial_value
  assert(max_value >= initial_value)
  return {
    value = initial_value,
    max_value = max_value or initial_value,

    ---@param self table
    acquire_nowait = function(self)
      if self.value >= self.max_value then return false end
      self.value = self.value + 1
      return true
    end,

    ---@param self table
    acquire = function(self, ms_timeout)
      local timeout = ms_timeout or defaults.timeout
      return wait(timeout, function()
        return self:acquire_nowait()
      end)
    end,

    ---@param self table
    release = function(self)
      self.value = self.value - 1
      if self.value < 0 then error(string.format("released too much tokens: %s", self.value)) end
    end,

    ---@param self table
    wait_until_empty = function(self, ms_timeout)
      local timeout = ms_timeout or defaults.timeout
      return wait(timeout, function()
        return self.value < 1
      end)
    end,
  }
end

function M.create_mutex()
  return M.create_semaphore(0, 1)
end

M.create_buf_mutex = (function()
  local state = {
    -- {bufnr: {lockname: mutex}}
    locks = {},

    ---@param self table
    get_or_create = function(self, bufnr, name)
      local lockname = string.format("sync.%s", name)
      if self.locks[bufnr] == nil then self.locks[bufnr] = {} end
      local lock = self.locks[bufnr][lockname]
      if lock == nil then
        lock = M.create_mutex()
        self.locks[bufnr][lockname] = lock
      end
      return lock
    end,
  }

  return function(bufnr, name)
    return state:get_or_create(bufnr, name)
  end
end)()

return M
