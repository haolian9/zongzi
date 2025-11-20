local M = {}
M.__index = M

local jelly = require("infra.jellyfish")("infra.VimRegex", "info")

---@class infra.VimRegex
---@field private impl vim.Regex
local VimRegex = {}
VimRegex.__index = VimRegex

---0-based; start inclusive, stop exclusive
---@alias infra.VimRegex.Iterator fun():(start_col:integer?,stop_col:integer?)

---@param str string
---@return infra.VimRegex.Iterator
function VimRegex:iter_str(str)
  local remain = str
  local offset = 0
  return function()
    ---0-based; start inclusive, stop inclusive
    local rel_start, rel_stop = self.impl:match_str(remain)
    if not (rel_start and rel_stop) then return end

    --str.sub uses 1-based index
    remain = string.sub(remain, rel_stop + 1)

    local start, stop = rel_start + offset, rel_stop + offset
    offset = offset + rel_stop

    return start, stop
  end
end

---@param bufnr integer
---@param lnum integer @0-based
---@param start_col? integer @0-based; nil=0
---@return infra.VimRegex.Iterator
function VimRegex:iter_line(bufnr, lnum, start_col)
  local offset = start_col or 0
  return function()
    ---0-based; start inclusive, stop inclusive
    local rel_start, rel_stop = self.impl:match_line(bufnr, lnum, offset)
    if not (rel_start and rel_stop) then return end

    local start, stop = rel_start + offset, rel_stop + offset
    offset = offset + rel_stop

    return start, stop
  end
end

---@param pattern string @vim \m regex
---@return infra.VimRegex?
function M:__call(pattern)
  ---as nvim reports no meaningful error on vim.regex(invalid-pattern), make it quiet
  local ok, regex = pcall(vim.regex, pattern)
  if not ok then return jelly.err("vim.regex: %s", regex) end

  return setmetatable({ impl = regex }, VimRegex)
end

---@param pattern string @vim \v regex
---@return infra.VimRegex?
function M.VeryMagic(pattern) return M:__call("\\v" .. pattern) end

---escape given pat as literals in \m mode
function M.magic_escape(pat) return vim.fn.escape(pat, [[.$*~\]]) end

---escape given pat as literals in \v mode
function M.verymagic_escape(pat) return vim.fn.escape(pat, [[.$*~()|\{<>]]) end

return setmetatable({}, M)
