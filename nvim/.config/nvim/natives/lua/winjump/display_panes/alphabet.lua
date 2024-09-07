local M = {}

local itertools = require("infra.itertools")
local strlib = require("infra.strlib")
local utf8 = require("infra.utf8")

local g = require("winjump.g")

local enum = (function()
  ---it's been written like this because `mod = require(str.format())` is not supported by squirrel.sort_requires
  local path = string.format("winjump.display_panes.fonts.%s", g.display_panes_font)
  return require(path)
end)()

local matrix = {}
for char, str in pairs(enum) do
  local lines = {}
  for line in strlib.iter_splits(str, "\n") do
    table.insert(lines, itertools.tolist(utf8.iterate(line)))
  end
  matrix[char] = lines
end

local size = {}
for char, lines in pairs(matrix) do
  local width = 0
  for _, line in ipairs(lines) do
    if #line > width then width = #line end
  end
  size[char] = { width = width, height = #lines }
end

---@param letter string @letter
---@return string
function M.raw(letter) return assert(enum[letter]) end

---@param letter string @letter
---@return string[][]
function M.matrix(letter) return assert(matrix[letter]) end

---@param letter string @letter
---@return {width: integer, height: integer} @max-width, height
function M.size(letter) return assert(size[letter]) end

return M
