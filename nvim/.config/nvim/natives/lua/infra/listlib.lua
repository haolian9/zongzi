local M = {}

-- iterate over list.values
---@param list any[]
---@return infra.Iterator.Any
function M.iter(list)
  local cursor = 1
  return function()
    if cursor > #list then return end
    local el = list[cursor]
    cursor = cursor + 1
    return el
  end
end

---@param list any[][] list of tuple
---@return fun():...any
function M.iter_unpacked(list)
  local iter = M.iter(list)
  return function() return unpack(iter() or {}) end
end

-- inplace extend
---@param a any[]
---@param b infra.Iterable.Any
function M.extend(a, b)
  local b_type = type(b)
  if b_type == "table" then
    for _, el in ipairs(b) do
      table.insert(a, el)
    end
  elseif b_type == "function" then
    for el in b do
      table.insert(a, el)
    end
  else
    error("unsupported type of b: " .. b_type)
  end
end

---@param queue any[]
---@return any?
function M.pop(queue)
  local len = #queue
  if len == 0 then return end
  -- idk if table.remove has such optimization
  local tail = queue[len]
  queue[len] = nil
  return tail
end

---@param queue any[]
function M.push(queue, el) table.insert(queue, 1, el) end

return M
