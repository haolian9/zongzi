local formatter = require("kite.formatter")
local scanner = require("kite.scanner")

local jelly = require("infra.jellyfish")("kite.state")

local M = {
  -- {root: {entries: [formated-path], cursor_line: 0-based-int, widest: #entry}}
  ---@type {[string]: {entries: string[]?, cursor_line: number?, widest: number?}}
  cache = {},
}

---@param root string
---@param key string
local function _get(root, key)
  local cache = M.cache[root]
  if cache == nil then return end
  return cache[key]
end

---@param root string
---@param key string
---@param val string[]|number?
local function _set(root, key, val)
  if M.cache[root] == nil then M.cache[root] = {} end
  M.cache[root][key] = val
end

---@param root string
---@param newval number?
---@return number?
function M:cursor_line(root, newval)
  ---@diagnostic disable-next-line
  if newval == nil then return _get(root, "cursor_line") end
  assert(newval > 0)
  _set(root, "cursor_line", newval)
end

function M:forget_entries(root)
  _set(root, "entries", nil)
end

---@return string[]
function M:entries(root)
  assert(root ~= nil)
  local entries = _get(root, "entries")

  if entries == nil then
    entries = scanner(root)
    _set(root, "entries", entries)
  end

  ---@diagnostic disable-next-line
  return entries
end

--get the max entry-width of the root
---@param root string
---@return number
function M:widest(root)
  local cache = self.cache[root]
  if cache ~= nil and cache.widest ~= nil then return cache.widest end
  local entries = self:entries(root)
  local widest = 0
  for _, entry in ipairs(entries) do
    local width = #entry
    if width > widest then widest = width end
  end
  self.cache[root].widest = widest
  return widest
end

--get the given formatted entry's index the entries
---@param entries string[]
---@param formatted string
---@param default ?number
---@return number
function M:entry_index(entries, formatted, default)
  for key, val in ipairs(entries) do
    if val == formatted then return key end
  end
  if default ~= nil then return default end
  jelly.err("entries=%s, formatted=%s, default=%s", vim.json.encode(entries), formatted, default)
  error("unreachable")
end

---@param to string
---@param from string?
function M:trail_behind(to, from)
  local function _heading()
    if from == nil then return "lost" end
    if to == from then return "stay" end
    if vim.startswith(to, from) then return "go_inside" end
    if vim.startswith(from, to) then return "go_outside" end
    return "lost"
  end

  local heading = _heading()
  if heading == "go_inside" then
    local outer, inner = from, to
    assert(outer)
    -- add trail outer->inner
    if self:cursor_line(outer) == nil then
      local inner_basename = vim.fs.basename(inner)
      self:cursor_line(outer, self:entry_index(self:entries(outer), formatter.dir(inner_basename)))
    end
    if self:cursor_line(inner) then return end
    self:cursor_line(inner, self:cursor_line(inner))
    return
  end
  if heading == "go_outside" then
    local outer, inner = to, from
    if self:cursor_line(outer) then return end
    -- add trail inner->outer
    local inner_basename = vim.fs.basename(inner)
    self:cursor_line(outer, self:entry_index(self:entries(outer), formatter.dir(inner_basename)))
    return
  end
  if heading == "lost" then
    if self:cursor_line(to) then return end
    self:cursor_line(to, 1)
    return
  end
  if heading == "stay" then return end
  error("unable to resolve trail")
end

return M
