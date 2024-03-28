local M = {}

local fn = require("infra.fn")
local utf8 = require("infra.utf8")

local raw = (function()
  local font = vim.go.background == "light" and "electronic" or "ansi_shadow"
  return require(string.format("winjump.display_panes.fonts.%s", font))
end)()

local matrix = {}
for char, str in pairs(raw) do
  local lines = {}
  for line in fn.split_iter(str, "\n") do
    table.insert(lines, fn.tolist(utf8.iterate(line)))
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
function M.raw(letter) return assert(raw[letter]) end

---@param letter string @letter
---@return string[][]
function M.matrix(letter) return assert(matrix[letter]) end

---@param letter string @letter
---@return {width: integer, height: integer} @max-width, height
function M.size(letter) return assert(size[letter]) end

return M
