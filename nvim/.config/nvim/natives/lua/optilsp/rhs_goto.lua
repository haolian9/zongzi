local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("optilsp.handlers")
local logging = require("infra.logging")
local ni = require("infra.ni")
local winsplit = require("infra.winsplit")

local sting = require("sting")
local log = logging.newlogger("optilsp.Goto", "info")
local lsp = vim.lsp
local lsputil = lsp.util

local GroupName = {}
do
  ---@param defn optilsp.GotoDefinition
  local function luals(defn) return string.format("%s:%s", defn.targetUri, defn.targetRange.start.line) end
  ---@param defn optilsp.GotoDefinition
  local function general(defn) return string.format("%s:%s", defn.uri, defn.range.start.line) end

  GroupName.luals = luals
  GroupName.zls = luals
  GroupName.pyright = general
  GroupName.clangd = general
  GroupName.gopls = general
  GroupName.phpactor = general
  GroupName.cmakels = general
end

---@class optilsp.handlers.Goto
---@field private method string
---@field private origin fun(...)
---@field private split_side? infra.winsplit.Side
---@field private group_name fun(defn: optilsp.GotoDefinition): string
local Goto = {}
do
  Goto.__index = Goto

  function Goto:__call()
    local params = lsputil.make_position_params()
    lsp.buf_request(0, self.method, params, function(...) return self:handler(...) end)
  end

  ---@private
  ---@param args {title: string, items: sting.Pickle[]}
  function Goto:on_list(args)
    local winid = ni.get_current_win()
    local loclist = sting.location.shelf(winid, string.format("%s locations", self.method))
    loclist:reset()
    loclist:extend(args.items)
    loclist:feed_vim(true, true)
  end

  ---@private
  ---@param result optilsp.GotoDefinition[]|optilsp.GotoDefinition
  function Goto:handler(_, result, ctx)
    -- stolen from $VIMRUNTIME/lua/vim/lsp/handlers.lua :: location_handler
    if result == nil then return jelly.info("No location found") end
    log.debug("gd result: %s", result)

    ---neither list nor dict
    if #result == 0 and next(result) == nil then return jelly.info("No location found: %s", result) end

    if self.split_side then winsplit(self.split_side) end

    ---it's GotoDefinition
    if result[1] == nil then return self.origin(_, result, ctx, { reuse_win = false }) end
    ---it's GotoDefinition[1]
    if #result == 1 then return self.origin(_, result[1], ctx, { reuse_win = false }) end

    ---distinct item based on file & start line
    local distinct = {}
    do
      local grouped = {}
      for _, ent in ipairs(result) do
        local key = self.group_name(ent)
        --only keep the first one
        if grouped[key] == nil then grouped[key] = ent end
      end
      distinct = dictlib.values(grouped)
    end

    self.origin(_, #distinct == 1 and distinct[1] or distinct, ctx, {
      on_list = function(args) self:on_list(args) end,
    })
  end
end

---@param langser string
---@param method string
---@param split_side? infra.winsplit.Side
---@return fun()
return function(langser, method, split_side)
  local g = setmetatable({
    method = method,
    origin = assert(lsp.handlers[method]),
    split_side = split_side,
    group_name = assert(GroupName[langser]),
  }, Goto)

  return function() g() end
end
