local M = {}

local jelly = require("infra.jellyfish")("infra.VimRegex", "info")
local strlib = require("infra.strlib")

local VimRegex
do
  ---@class infra.VimRegex
  ---@field pattern string
  ---@field private impl vim.Regex
  local Impl = {}
  Impl.__index = Impl

  ---0-based; start inclusive, stop exclusive
  ---@alias infra.VimRegex.Iterator fun():(start_col:integer?,stop_col:integer?)

  ---@param str string
  ---@return infra.VimRegex.Iterator
  function Impl:iter_str(str)
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
  function Impl:iter_line(bufnr, lnum, start_col)
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
  ---@return infra.VimRegex
  function VimRegex(pattern)
    ---as nvim reports no meaningful error on vim.regex(invalid-pattern), make it quiet
    local ok, regex = pcall(vim.regex, pattern)
    if not ok then return jelly.fatal("ValueError", "invalid pattern: %s", regex) end
    return setmetatable({ pattern = pattern, impl = regex }, Impl)
  end
end

---@param pattern string
---@return string
function M.escape_for_verymagic(pattern) return vim.fn.escape(pattern, [[.$*~()|\{<>]]) end

---@param str string
---@return string
function M.escape_for_verynomagic(str) return vim.fn.escape(str, [[\]]) end

---user input friendly
---@param pattern string
---@return infra.VimRegex
function M.VeryMagic(pattern)
  if not strlib.startswith(pattern, [[\v]]) then --
    pattern = [[\v]] .. pattern
  end
  return VimRegex(pattern)
end

---fixedstr friendly
---@param pattern string
---@return infra.VimRegex
function M.VeryNoMagic(pattern)
  if not strlib.startswith(pattern, [[\V]]) then --
    pattern = [[\V]] .. pattern
  end
  return VimRegex(pattern)
end

---@param str string
---@return infra.VimRegex
function M.FixedStr(str)
  assert(not strlib.startswith(str, [[\V]]))
  return VimRegex([[\V]] .. M.escape_for_verynomagic(str))
end

return setmetatable(M, { __call = function(_, pattern) return VimRegex(pattern) end })
