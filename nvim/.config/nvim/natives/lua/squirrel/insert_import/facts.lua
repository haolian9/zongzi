local M = {}

do
  ---@type TSNode
  local origin = {}
  function origin:start() return 0, 0 end
  function origin:end_() return 0, 0 end
  function origin:range() return 0, 0, 0, 0 end

  M.origin = origin
end

return M
