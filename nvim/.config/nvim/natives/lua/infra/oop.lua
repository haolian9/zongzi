local M = {}

function M.dotize(impl)
  return setmetatable({}, {
    __index = function(t, key)
      local f = function(...) return impl[key](impl, ...) end
      t[key] = f
      return f
    end,
  })
end

return M
