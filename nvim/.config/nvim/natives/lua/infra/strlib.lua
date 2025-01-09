local M = {}

local new_table = require("table.new")

--forced to plain-match
---@param haystack string
---@param needle string
---@param start? number
function M.find(haystack, needle, start) return string.find(haystack, needle, start, true) end

function M.contains(haystack, needle, start) return select(1, M.find(haystack, needle, start)) ~= nil end

---differ to string.sub, (start:0, stop:0]
---@param str string
---@param start integer @0-based, inclusive
---@param stop? integer @0-based, exclusive
function M.slice(str, start, stop)
  if stop == nil then
    start, stop = 0, start
  end

  return string.sub(str, start + 1, stop)
end

do
  local function rfind(haystack, needle)
    assert(#needle >= 1)
    for i = #haystack - #needle, 1, -1 do
      local found = string.sub(haystack, i, i + #needle - 1)
      if found == needle then return i end
    end
  end

  ---@param haystack string
  ---@param needle string
  ---@return nil|number
  function M.rfind(haystack, needle)
    local impl
    do
      local ok, cthulhu = pcall(require, "cthulhu")
      --the ffi version is 4x faster but no difference on memory usage
      impl = ok and cthulhu.str.rfind or rfind
    end

    M.rfind = impl

    return impl(haystack, needle)
  end
end

---@param str string
---@return string[]
function M.tolist(str)
  local list = new_table(#str, 0)
  for i = 1, #str do
    list[i] = string.sub(str, i, i)
  end
  return list
end

---@param str string
---@return {[string]: true}
function M.toset(str)
  local set = new_table(0, #str)
  for i = 1, #str do
    set[string.sub(str, i, i)] = true
  end
  return set
end

do
  local blanks = M.toset("\t\n ")

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

  ---@param str string
  ---@param chars? string @nil=blank chars
  ---@return string
  function M.lstrip(str, chars)
    local mask = chars and M.toset(chars) or blanks
    local start_at = lstrip_pos(str, mask)

    if start_at == 1 then return str end
    return string.sub(str, start_at, #str)
  end

  ---@param str string
  ---@param chars? string @nil=blank chars
  ---@return string
  function M.rstrip(str, chars)
    local mask = chars and M.toset(chars) or blanks
    local stop_at = rstrip_pos(str, mask)

    if stop_at == #str then return str end
    return string.sub(str, 1, stop_at)
  end

  ---@param str string
  ---@param chars? string @nil=blank chars
  ---@return string
  function M.strip(str, chars)
    local mask = chars and M.toset(chars) or blanks
    local start_at = lstrip_pos(str, mask)
    local stop_at = rstrip_pos(str, mask)

    if start_at == 1 and stop_at == #str then return str end
    return string.sub(str, start_at, stop_at)
  end
end

---@param a string
---@param b string
---@return boolean
function M.startswith(a, b)
  if #b > #a then return false end
  if #b == #a then return a == b end
  return string.sub(a, 1, #b) == b
end

---@param a string
---@param b string
---@return boolean
function M.endswith(a, b)
  if #b > #a then return false end
  if #b == #a then return a == b end
  return string.sub(a, -#b) == b
end

do
  -- parts can be empty string
  ---@param str string
  ---@param delimiter string
  ---@param maxsplit number? @specified or infinited
  ---@param keepend boolean? @specified or false
  ---@return fun():string?
  function M.iter_splits(str, delimiter, maxsplit, keepend)
    keepend = keepend or false

    local cursor = 1
    local remain_splits = (maxsplit or math.huge) + 1

    return function()
      if remain_splits < 1 then return end

      if remain_splits == 1 then
        remain_splits = 0
        return str:sub(cursor)
      end

      local del_start, del_stop = str:find(delimiter, cursor, true)
      if del_start == nil or del_stop == nil then
        remain_splits = 0
        return str:sub(cursor)
      end

      remain_splits = remain_splits - 1
      local start = cursor
      local stop = del_start - 1
      if keepend then stop = del_stop end
      cursor = del_stop + 1
      return str:sub(start, stop)
    end
  end

  ---parts can be empty string
  ---@param str string
  ---@param delimiter string
  ---@param maxsplit number? @specified or infinited
  ---@param keepend boolean? @specified or false
  ---@return string[]
  function M.splits(str, delimiter, maxsplit, keepend)
    local iter = M.iter_splits(str, delimiter, maxsplit, keepend)

    local list = {}
    for chunk in iter do
      table.insert(list, chunk)
    end
    return list
  end
end

---@param ... string
---@return fun(str:string):matched:boolean
function M.Glob(...)
  local pattern = vim.glob.to_lpeg(select(1, ...))
  for i = 2, select("#", ...) do
    pattern = pattern + vim.glob.to_lpeg(select(i, ...))
  end
  return function(str) return pattern:match(str) ~= nil end
end

return M
