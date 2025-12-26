local M = {}

local jelly = require("infra.jellyfish")("infra.dictlib")

---NB: no order guarantee
---@generic K
---@param dict {[K]: any}
---@return K[]
function M.keys(dict)
  local keys = {}
  for key, _ in pairs(dict) do
    table.insert(keys, key)
  end
  return keys
end

---@generic V
---@param dict {[any]: V}
---@return V[]
function M.values(dict)
  local values = {}
  for _, val in pairs(dict) do
    table.insert(values, val)
  end
  return values
end

---@generic K
---@generic V
---@param dict {[K]: V}
---@return K?,V?
function M.items(dict)
  local i
  return function()
    local k, v = next(dict, i)
    i = k
    return k, v
  end
end

---@generic K
---@generic V
---@param dict {[K]: V}
---@return V?,K?
function M.flipped(dict)
  local flipped = {}
  for key, val in pairs(dict) do
    flipped[val] = key
  end
  return flipped
end

--the later keys win
---@param ... table
---@return table
function M.merged(...)
  local merged = {}
  for i = 1, select("#", ...) do
    for k, v in pairs(select(i, ...)) do
      merged[k] = v
    end
  end
  return merged
end

--inplace merge
---@param a table
---@param ... table
function M.merge(a, ...)
  for i = 1, select("#", ...) do
    for k, v in pairs(select(i, ...)) do
      a[k] = v
    end
  end
end

---@param cap integer
---@param weakable_value? boolean @nil=false
---@return table
function M.CappedDict(cap, weakable_value)
  if weakable_value == nil then weakable_value = false end

  local remain = cap

  ---'k' makes no sense, since keys are string always in my use
  local mode = weakable_value and "v" or nil

  ---wrorkaround to maintain a reasonable 'remain' value, as get() and set() always apear in pairs
  local index = weakable_value and function() remain = remain + 1 end or nil

  return setmetatable({}, {
    __mode = mode,
    __index = index,
    __newindex = function(t, k, v)
      local exists = rawget(t, k) ~= nil
      if exists then
        rawset(t, k, v)
        if v == nil then remain = remain + 1 end
      else
        if remain == 0 then return jelly.fatal("OverflowError", "cap=%d keys=%s", cap, M.keys(t)) end
        rawset(t, k, v)
        if v ~= nil then remain = remain - 1 end
      end
    end,
  })
end

---NB: no order guarantee
---@generic K
---@param dict {[K]: any}
---@return fun(): K?
function M.iter_keys(dict)
  local iter = pairs(dict)
  local key

  return function()
    key = iter(dict, key)
    return key
  end
end

---NB: no order guarantee
---@generic V
---@param dict {[any]: V}
---@return fun(): V?
function M.iter_values(dict)
  local iter = pairs(dict)
  local key

  return function()
    local val
    key, val = iter(dict, key)
    return val
  end
end

---@param dreams table
---@param ... any @traces
function M.get(dreams, ...)
  local layer = dreams
  for i = 1, select("#", ...) do
    local path = select(i, ...)
    if type(layer) ~= "table" then return end
    layer = layer[path]
    if layer == nil then return end
  end
  return layer
end

---@param dict table
---@param keys any[]
---@param val any
function M.set(dict, keys, val)
  local bag = dict
  for i = 1, #keys - 1 do
    local key = keys[i]
    if bag[key] == nil then
      bag[key] = {}
    elseif type(bag[key]) == "table" then
      --pass
    else
      return jelly.fatal("ValueError", "value of key=%s is not a table: %s", key, bag[key])
    end
    bag = bag[key]
  end
  assert(type(bag) == "table")
  bag[keys[#keys]] = val
end

return M
