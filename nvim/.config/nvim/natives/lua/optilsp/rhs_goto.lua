local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("optilsp.handlers")
local logging = require("infra.logging")
local winsplit = require("infra.winsplit")

local sting = require("sting")

local api = vim.api
local log = logging.newlogger("optilsp.Goto", "info")
local lsp = vim.lsp
local lsputil = lsp.util

local key_generators
do
  ---@param defn optilsp.GotoDefinition
  local function luals(defn) return string.format("%s:%s", defn.targetUri, defn.targetRange.start.line) end
  ---@param defn optilsp.GotoDefinition
  local function general(defn) return string.format("%s:%s", defn.uri, defn.range.start.line) end
  key_generators = {
    luals = luals,
    zls = luals,
    pyright = general,
    clangd = general,
    gopls = general,
    phpactor = general,
  }
end

---@class optilsp.handlers.Goto
---@field private method string
---@field private origin fun(...)
---@field private split_side? infra.winsplit.Side
---@field private gen_key fun(defn: optilsp.GotoDefinition): string
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
    local winid = api.nvim_get_current_win()
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

    --neither list nor dict
    if #result == 0 and next(result) == nil then return jelly.info("No location found: %s", result) end

    if self.split_side then winsplit(self.split_side) end

    --it's a GotoDefinition
    if result[1] == nil then return self.origin(_, result, ctx, { reuse_win = false }) end

    --distinct item based on file & start line
    local distinct = {}
    do
      local grouped = {}
      for _, ent in ipairs(result) do
        local key = self.gen_key(ent)
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
    gen_key = assert(key_generators[langser]),
  }, Goto)

  return function() g() end
end
