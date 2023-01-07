local M = {}

-- full match, but no order guarantee
---@param _haystack string @lower
---@param _needle string @lower
function M.match_lower(_haystack, _needle)
  -- todo: lru cache for argument or result?
  -- todo: bool result or scoring?

  local haystack = {}
  for i = 1, #_haystack do
    haystack[string.sub(_haystack, i, i)] = true
  end

  for i = 1, #_needle do
    if not haystack[string.sub(_needle, i, i)] then return false end
  end
  return true
end

---@param _haystack string @lower
---@param _needle string @lower
function M.similar_lower(_haystack, _needle)
  local haystack = {}
  for i = 1, #_haystack do
    haystack[string.sub(_haystack, i, i)] = true
  end

  -- char: 一个匹配得一分，重复char重复算分；不匹配不扣分
  -- 得分占 needle 长度百分比
  local matches = 0
  for i = 1, #_needle do
    if haystack[string.sub(_needle, i, i)] then matches = matches + 1 end
  end

  return (matches / #_needle) * 100
end

function M.test()
  local haystack = "stuff in plugin/ arent lua modules"
  do
    local needle = "siaarent"
    print(M.match_lower(haystack, needle))
  end
  do
    print(M.similar_lower(haystack, "sia"))
    print(M.similar_lower(haystack, "six"))
    print(M.similar_lower(haystack, "soxz"))
  end
end

return M
