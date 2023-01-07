local M = {}

---@param haystack string
---@param substr string
---@return nil|number
function M.rfind(haystack, substr)
  assert(#substr >= 1)
  for i = #haystack - #substr, 1, -1 do
    local found = string.sub(haystack, i, i + #substr - 1)
    if found == substr then return i end
  end
end

local function lstrip_pos(str, mask)
  local start_at = 1
  -- +1 for case ('/', '/')
  for i = 1, #str + 1 do
    local char = string.sub(str, i, i)
    start_at = i
    if mask[char] == nil then break end
  end
  return start_at
end

local function rstrip_pos(str, mask)
  local stop_at = #str
  -- -1 for case ('/', '/')
  for i = #str, 1 - 1, -1 do
    local char = string.sub(str, i, i)
    stop_at = i
    if mask[char] == nil then break end
  end
  return stop_at
end

local function make_strip_mask(chars)
  local mask = {}
  for i = 1, #chars do
    mask[string.sub(chars, i, i)] = true
  end
  return mask
end

function M.lstrip(str, chars)
  local mask = make_strip_mask(chars)
  local start_at = lstrip_pos(str, mask)

  if start_at == 1 then return str end
  return string.sub(str, start_at, #str)
end

function M.rstrip(str, chars)
  local mask = make_strip_mask(chars)
  local stop_at = rstrip_pos(str, mask)

  if stop_at == #str then return str end
  return string.sub(str, 1, stop_at)
end

function M.strip(str, chars)
  local mask = make_strip_mask(chars)
  local start_at = lstrip_pos(str, mask)
  local stop_at = rstrip_pos(str, mask)

  if start_at == 1 and stop_at == #str then return str end
  return string.sub(str, start_at, stop_at)
end

return M
