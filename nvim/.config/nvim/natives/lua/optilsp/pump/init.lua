local M = {}

local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("optilsp.pump", "info")
local logging = require("infra.logging")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local Extractor = require("optilsp.pump.Extractor")

local log = logging.newlogger("optilsp.pump", "info")

local state = { bufnr = nil, winid = nil }
do
  function state:has_valid_buf() return self.bufnr ~= nil and ni.buf_is_valid(self.bufnr) end
  function state:has_valid_win() return self.winid ~= nil and ni.win_is_valid(self.winid) end
end

local interpret_event
do
  ---@param bufnr integer
  ---@param compitem table @depends on langserver
  ---@return nil|string[]
  local function extract_lines(bufnr, compitem)
    local langser
    do
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      --todo: v0.11 - multiple lsp clients
      assert(#clients == 1, "suppose there is only one active langserver")
      langser = clients[1].name
    end

    local extract = Extractor[langser]
    if extract == nil then return jelly.warn("no extractor for %s", langser) end

    return extract(compitem)
  end

  --at screen/editor level
  ---@param event optilsp.CompleteEvent
  ---@param max_width integer
  ---@return nil|{width: integer, height: integer, row: integer, col: integer}
  local function resolve_winopts(event, max_width)
    local pum_col_start = event.col
    local pum_col_end = pum_col_start + event.width

    local right
    do
      local margin = math.max(vim.go.columns - (pum_col_end + 1), 0)
      if margin < 20 then
        right = { width = 0, row = 0, col = 0 }
      else
        right = { width = math.min(max_width, margin), col = pum_col_end + 1 }
      end
    end

    local left
    do
      local margin = math.max(pum_col_start - 1, 0)
      if margin < 20 then
        left = { width = 0, row = 0, col = 0 }
      else
        local w = math.min(max_width, margin)
        left = { width = w, col = pum_col_start - w }
      end
    end

    local winopts = right.width >= left.width and right or left

    if winopts.width == 0 then return jelly.warn("no enough room to show preview") end

    return winopts
  end

  ---@param event optilsp.CompleteEvent
  ---@return nil|string[],nil|{width: integer, height: integer, row: integer, col: integer}
  function interpret_event(bufnr, event)
    local ok, compitem = pcall(dictlib.get, event, "completed_item", "user_data", "nvim", "lsp", "completion_item")
    if not ok then return end --so the event is not delivered by vim.lsp
    if compitem == nil then return end

    log.debug("%s", compitem)

    local lines = extract_lines(bufnr, compitem)
    if lines == nil then return end
    if #lines == 0 then return end

    local max_width = its(lines):map(function(line) return #line end):max() or 0
    if max_width == 0 then return end

    -- add paddings
    table.insert(lines, 1, "")
    table.insert(lines, "")

    local winopts = resolve_winopts(event, max_width)
    if winopts == nil then return end

    --todo: winopts.row should be the same line with the current selected pum item
    winopts.row = event.row
    winopts.height = math.min(vim.go.lines - vim.go.cmdheight, #lines)

    return lines, winopts
  end
end

local function hide_preview()
  if not state:has_valid_win() then return end
  ni.win_close(state.winid, true)
  state.winid = nil
end

---@param host_bufnr integer
---@param event optilsp.CompleteEvent
local function show_preview(host_bufnr, event)
  if not state:has_valid_buf() then state.bufnr = Ephemeral({ bufhidden = "unload", namepat = "pump://{bufnr}" }) end

  local lines, winopts = interpret_event(host_bufnr, event)

  -- vim.schedule exists for escaping from textlock
  vim.schedule(function()
    if not (lines and winopts) then return hide_preview() end

    buflines.replaces_all(state.bufnr, lines)

    if state:has_valid_win() then
      ni.win_set_width(state.winid, winopts.width)
      ni.win_set_height(state.winid, winopts.height)
      jelly.debug("new width=%d, height=%d", winopts.width, winopts.height)
    else
      dictlib.merge(winopts, { noautocmd = true, relative = "editor" })
      state.winid = rifts.open.win(state.bufnr, false, winopts)
      prefer.wo(state.winid, "wrap", true)
    end
  end)
end

function M.init()
  M.init = nil

  local aug = augroups.Augroup("optilsp://pump")
  aug:repeats("CompleteChanged", {
    callback = function() show_preview(ni.get_current_buf(), vim.v.event) end,
  })
  aug:repeats("CompleteDone", {
    callback = function()
      if vim.fn.pumvisible() == 1 then return end
      hide_preview()
    end,
  })
end

return M
