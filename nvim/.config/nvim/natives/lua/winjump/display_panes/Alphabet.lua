local M = {}

local itertools = require("infra.itertools")
local strlib = require("infra.strlib")
local utf8 = require("infra.utf8")

---@class winjump.display_panes.Alphabet
---@field private _raw    {[string]: string}
---@field private _matrix {[string]: string[][]}
---@field private _size   {[string]: {width:integer, height:integer}}
local Alphabet = {}
do
  Alphabet.__index = Alphabet

  ---@param letter string
  ---@return string
  function Alphabet:raw(letter) return assert(self._raw[letter]) end

  ---@param letter string
  ---@return string[][]
  function Alphabet:matrix(letter) return assert(self._matrix[letter]) end

  ---@param letter string
  ---@return {width: integer, height: integer} @max-width, height
  function Alphabet:size(letter) return assert(self._size[letter]) end
end

---@param font string
---@return winjump.display_panes.Alphabet
return function(font)
  local raw = require("winjump.display_panes.fonts." .. font)

  local matrix = {}
  for char, str in pairs(raw) do
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

  return setmetatable({ _raw = raw, _matrix = matrix, _size = size }, Alphabet)
end
