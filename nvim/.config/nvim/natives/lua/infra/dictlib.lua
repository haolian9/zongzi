local M = {}

local jelly = require("infra.jellyfish")("infra.dictlib")

---@alias Dict {[any]: any}

---NB: no order guarantee
---@param dict Dict
---@return any[]
function M.keys(dict)
  local keys = {}
  for key, _ in pairs(dict) do
    table.insert(keys, key)
  end
  return keys
end

---@param dict Dict
---@return any[]
function M.values(dict)
  local values = {}
  for _, val in pairs(dict) do
    table.insert(values, val)
  end
  return values
end

---@param dict Dict
---@return Dict
function M.flipped(dict)
  local flipped = {}
  for key, val in pairs(dict) do
    flipped[val] = key
  end
  return flipped
end

--the later keys win
---@param ... Dict
---@return Dict
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
---@param a Dict
---@param ... Dict
function M.merge(a, ...)
  for i = 1, select("#", ...) do
    for k, v in pairs(select(i, ...)) do
      a[k] = v
    end
  end
end

---@param dreams Dict
---@param ... string|number @trace
function M.get(dreams, ...)
  local layer = dreams
  for _, path in ipairs({ ... }) do
    assert(type(layer) == "table", path)
    layer = layer[path]
    if layer == nil then return end
  end
  return layer
end

---@param cap integer
---@param weakable_value? boolean @nil=false
---@return Dict
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
        if remain == 0 then
          jelly.err("keys: %s", table.concat(M.keys(t), " "))
          error("full", cap)
        end
        rawset(t, k, v)
        if v ~= nil then remain = remain - 1 end
      end
    end,
  })
end

return M
