--- the names, pickle and shelf, come from python, which are its stdlibs

local M = {}

local fs = require("infra.fs")
local its = require("infra.its")
local listlib = require("infra.listlib")
local strlib = require("infra.strlib")

---@class sting.Pickle
---@field bufnr? number
---@field filename? string
---@field module? string
---@field lnum number @1-based
---@field end_lnum? number @1-based
---@field col number @0-based
---@field end_col? number @0-based, exclusive?
---@field vcol? 0|1
---@field text string
---@field type? 'E'|'W'|'N'
---@field pattern? string
---@field nr? number
---@field valid? 0|1

do
  ---customs:
  ---* patten = '{fpath}|{lnum}|{text}'
  ---* {fpath} will be shortened or bufnr or empty
  ---* {col} no more
  ---* {text} will be left-trimmed
  ---@param pickle sting.Pickle
  ---@return string @pattern='<filename>|<lnum> col <col>|<text>'
  local function default_flavor(pickle)
    local text
    if pickle.text ~= nil then
      text = strlib.lstrip(pickle.text)
    else
      text = ""
    end

    local fpath
    if pickle.filename ~= nil then
      fpath = fs.shorten(pickle.filename, true)
    elseif pickle.bufnr ~= nil then
      fpath = string.format("buf#%d", pickle.bufnr)
    else
      fpath = ""
    end

    local lnum = pickle.lnum or 0

    return string.format("%s|%d|%s", fpath, lnum, text)
  end

  ---@class sting.Shelf
  ---@field private name string
  ---@field private flavor? fun(pickle: sting.Pickle): string
  ---@field private shelf sting.Pickle[]
  local Impl = {}

  Impl.__index = Impl

  function Impl:reset() self.shelf = {} end

  ---@param pickle sting.Pickle
  function Impl:append(pickle) table.insert(self.shelf, pickle) end

  ---@param list sting.Pickle[]
  function Impl:extend(list) listlib.extend(self.shelf, list) end

  --NB: to avoid re-fill nvim the same list requires too much logic,
  --which i dont think is worth it, and it'll not in a high frenquency
  ---@param open_win boolean
  ---@param goto_first boolean
  function Impl:feed_vim(open_win, goto_first) error("not implemented") end

  ---@private
  ---@param info {quickfix: 0|1, winid: integer, id: integer, start_idx: integer, end_idx: integer}
  ---@return string[]
  function Impl:quickfixtextfunc(info)
    assert(self.flavor ~= nil)
    assert(info.start_idx == 1 and info.end_idx == #self.shelf)
    return its(self.shelf):map(self.flavor):tolist()
  end

  ---@param name string
  ---@param flavor? true|(fun(pickle: sting.Pickle): string)
  ---@return sting.Shelf
  function M.Shelf(name, flavor)
    if flavor == true then flavor = default_flavor end
    return setmetatable({ name = name, shelf = {}, flavor = flavor }, Impl)
  end
end

return M
