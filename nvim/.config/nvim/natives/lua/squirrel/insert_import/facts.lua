local M = {}

do
  ---@type TSNode
  local origin = {}
  function origin:start() return -1, 0 end
  function origin:end_() return -1, 0 end
  function origin:range() return -1, 0, -1, 0 end

  M.origin = origin
end

return M
