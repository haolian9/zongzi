local impl = require("infra.LRU.impl")

---@param cap integer
return function(cap)
  local get, set = impl(cap)

  --todo: can not make __pairs work

  return setmetatable({}, {
    __index = get,
    __newindex = set,
  })
end
