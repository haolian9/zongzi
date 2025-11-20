local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("sting.location")
local mi = require("infra.mi")
local ni = require("infra.ni")

local puff = require("puff")
local toggle = require("sting.toggle")
local types = require("sting.types")

---@param room sting.location.Room
---@param name string
local function Shelf(room, name)
  local shelf = types.Shelf(name, true)
  ---@diagnostic disable-next-line: inject-field
  shelf.room = room

  function shelf:feed_vim(open_win, goto_first)
    ---@diagnostic disable: invisible
    vim.fn.setloclist(self.room.winid, {}, "f")
    if self.flavor == nil then
      vim.fn.setloclist(self.room.winid, self.shelf, " ", { title = self.name })
    else
      vim.fn.setloclist(self.room.winid, {}, " ", { title = self.name, items = self.shelf, quickfixtextfunc = function(...) return self:quickfixtextfunc(...) end })
    end

    if not open_win then return end
    toggle.open_locwin()

    if not goto_first then return end
    ex.eval("ll 1")
  end
  return shelf
end

local Room
do
  ---@class sting.location.Room
  ---@field private winid number
  ---@field private last_fed_name string?
  ---@field private shelves {[string]: sting.Shelf}
  local Impl = {}
  Impl.__index = Impl

  ---@param name string
  function Impl:shelf(name)
    if self.shelves[name] == nil then self.shelves[name] = Shelf(self, name) end
    return self.shelves[name]
  end

  function Impl:switch()
    local choices = dictlib.keys(self.shelves)
    if #choices == 0 then return jelly.info("no location shelves") end
    puff.select(choices, { prompt = string.format("switch location shelves in win#%d", self.winid) }, function(name)
      if name == nil then return end
      if name == self.last_fed_name then return end
      assert(self.shelves[name]):feed_vim(true, false)
    end)
  end

  function Room(winid) return setmetatable({ winid = winid, shelves = {} }, Impl) end
end

---@type {[integer]: sting.location.Room}
local rooms = {}

do
  local aug = augroups.Augroup("sting://location")

  aug:repeats("WinClosed", {
    callback = function(args)
      local winid = tonumber(args.match)
      assert(winid ~= nil and winid >= 1000)
      rooms[winid] = nil
    end,
  })
end

function M.shelf(winid, name)
  assert(winid ~= nil and winid ~= 0)
  if rooms[winid] == nil then rooms[winid] = Room(winid) end
  return rooms[winid]:shelf(name)
end

function M.switch(winid)
  winid = mi.resolve_winid_param(winid)
  assert(winid ~= 0)
  if rooms[winid] == nil then return jelly.info("no shelves under win#%d", winid) end
  rooms[winid]:switch()
end

function M.clear() rooms = {} end

return M
