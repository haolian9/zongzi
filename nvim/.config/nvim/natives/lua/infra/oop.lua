local M = {}

---@generic T
---@param impl T
---@return T
function M.dotize(impl)
  return setmetatable({}, {
    __index = function(t, key)
      local f = function(...) return impl[key](impl, ...) end
      rawset(t, key, f)
      return f
    end,
  })
end

---@generic T
---@param base T
---@param attrfn fun(attr:string):any
---@return T
function M.lazyattrs(base, attrfn)
  return setmetatable(base, {
    __index = function(t, k)
      local v = attrfn(k)
      rawset(t, k, v)
      return v
    end,
  })
end

return M
