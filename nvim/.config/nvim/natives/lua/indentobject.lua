-- design choices
-- * not work on top level
-- * ignore indent=0 when searching next/prev line
-- * ignore blank lines in the top and bottom of the range

local buflines = require("infra.buflines")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("indentobject")
local jumplist = require("infra.jumplist")
local ni = require("infra.ni")
local vsel = require("infra.vsel")
local wincursor = require("infra.wincursor")

local is_empty_line
do
  function is_empty_line(bufnr, lnum) return buflines.partial_line(bufnr, lnum, 0, 1) == "" end

  local ok, cthulhu = pcall(require, "cthulhu")
  if ok then is_empty_line = cthulhu.nvim.is_empty_line end
end

---@param bufnr integer
---@param nsp integer
---@param range fun():integer? @range of rows
---@return integer @row
local function resolve_stop_row(bufnr, nsp, range)
  local result
  for row in range do
    local insp = vim.fn.indent(row)
    if insp == 0 then
      if not is_empty_line(bufnr, row - 1) then break end
      -- skip blank line
    elseif insp < nsp then
      break
    else
      result = row
    end
  end
  assert(result ~= nil)
  return result
end

return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  local curow = wincursor.row(winid)
  local nsp = vim.fn.indent(curow)
  if nsp == 0 then return jelly.err("refuse to work on top indent level") end

  local toprow = resolve_stop_row(bufnr, nsp, itertools.range(curow, 0 - 1, -1))
  local botrow = resolve_stop_row(bufnr, nsp, itertools.range(curow, buflines.count(bufnr) + 1, 1))

  jelly.debug("curow=%d, nsp=%d, rowrange=%d-%d", curow, nsp, toprow, botrow)
  jumplist.push_here()
  vsel.select_lines(winid, toprow - 1, botrow - 1 + 1)
end
