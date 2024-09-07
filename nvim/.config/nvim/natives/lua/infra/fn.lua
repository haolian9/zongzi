local M = {}

do
  local function evaluate(thing)
    if type(thing) == "function" then return thing() end
    return thing
  end

  function M.either(truthy, a, b)
    if evaluate(truthy) then return evaluate(a) end
    return evaluate(b)
  end
end

---equals to `a ~= nil and a or b`
---suppose `a: nil|false|any`
function M.nilthen(a, b)
  if a == nil then return b end
  return a
end

return M
