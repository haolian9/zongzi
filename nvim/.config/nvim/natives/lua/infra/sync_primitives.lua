local M = {}

local defaults = {
  -- unit: ms
  interval = 100,
  -- unit: ms
  timeout = 3000,
}

do
  ---@param ms_timeout integer
  ---@param predicate? fun(): boolean
  ---@param check_interval? integer
  ---@return boolean
  local function wait(ms_timeout, predicate, check_interval)
    local interval = check_interval or defaults.interval
    local finished, extra = vim.wait(ms_timeout, predicate, interval)
    if extra == -2 then error("canceled by user") end
    return finished
  end

  ---@class infra.sync.Semaphore
  ---@field private value integer
  ---@field private max_value integer
  local Semaphore = {}

  Semaphore.__index = Semaphore

  function Semaphore:acquire_nowait()
    if self.value >= self.max_value then return false end
    self.value = self.value + 1
    return true
  end

  ---@param ms_timeout? integer
  ---@return boolean
  function Semaphore:acquire(ms_timeout)
    local timeout = ms_timeout or defaults.timeout
    return wait(timeout, function() return self:acquire_nowait() end)
  end

  function Semaphore:release()
    self.value = self.value - 1
    if self.value < 0 then error(string.format("released too much tokens: %s", self.value)) end
  end

  ---@param ms_timeout integer
  ---@return boolean
  function Semaphore:wait_until_empty(ms_timeout)
    local timeout = ms_timeout or defaults.timeout
    return wait(timeout, function() return self.value < 1 end)
  end

  ---api design is stolen from trio.Semaphore
  ---no re-entrance
  ---@param initial_value integer
  ---@param max_value? integer @nil=initial_value
  function M.Semaphore(initial_value, max_value)
    assert(initial_value >= 0)
    max_value = max_value or initial_value
    assert(max_value >= initial_value)

    return setmetatable({ value = initial_value, max_value = max_value or initial_value }, Semaphore)
  end
end

function M.Mutex() return M.Semaphore(0, 1) end

do
  local state = {}

  ---{bufnr: {lockname: mutex}}
  ---@type {[integer]: {[string]: infra.sync.Semaphore}}
  state.locks = {}

  ---@param bufnr integer
  ---@param name string
  ---@return infra.sync.Semaphore
  function state:get_or_create(bufnr, name)
    local lockname = string.format("sync.%s", name)
    if self.locks[bufnr] == nil then self.locks[bufnr] = {} end
    local lock = self.locks[bufnr][lockname]
    if lock == nil then
      lock = M.Mutex()
      self.locks[bufnr][lockname] = lock
    end
    return lock
  end

  ---@param bufnr integer
  ---@param name string
  function M.BufMutex(bufnr, name) return state:get_or_create(bufnr, name) end
end

return M
