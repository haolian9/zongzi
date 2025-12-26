local M = {}

---@alias StrSet {[string]: true}

---@param a StrSet
---@param b StrSet
---@return string[]
function M.intersect(a, b)
  local intersect = {}
  for member in pairs(a) do
    if b[member] then table.insert(intersect, member) end
  end
  return intersect
end

---@param a StrSet
---@param b StrSet
---@return string[]
function M.diff(a, b)
  local intersect = {}
  for member in pairs(a) do
    if b[member] == nil then table.insert(intersect, member) end
  end
  return intersect
end

---@generic T
---@param ... T
---@return table<T,true>
function M.new(...)
  local set = {}
  for i = 1, select("#", ...) do
    set[select(i, ...)] = true
  end
  return set
end

return M
