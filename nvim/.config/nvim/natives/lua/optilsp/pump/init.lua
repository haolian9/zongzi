local M = {}

local Augroup = require("infra.Augroup")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("optilsp.pump")
local listlib = require("infra.listlib")
local logging = require("infra.logging")
local rifts = require("infra.rifts")

local api = vim.api

local log = logging.newlogger("optilsp.pump", "info")

local state = { bufnr = nil, winid = nil }
do
  function state:has_valid_buf() return self.bufnr ~= nil and api.nvim_buf_is_valid(self.bufnr) end
  function state:has_valid_win() return self.winid ~= nil and api.nvim_win_is_valid(self.winid) end
end

---@type {[string]: fun(compitem: optilsp.CompItem): string[]}
local extractors = {}
do
  --todo: respect documentation.kind
  --todo: line overflow
  --todo: labelDetails: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemLabelDetails

  local sepline = "-----"

  function extractors.clangd(compitem)
    local lines = {}
    local need_sepline = false

    local label = compitem.label
    local detail = compitem.detail
    if label or detail then
      table.insert(lines, (detail or "") .. (label or ""))
      need_sepline = true
    end

    local doc = compitem.documentation
    if doc ~= nil then
      if need_sepline then table.insert(lines, sepline) end
      local plain = type(doc) == "string" and doc or assert(doc.value)
      listlib.extend(lines, fn.split_iter(plain, "\n"))
      need_sepline = true
    end

    return lines
  end

  function extractors.luals(compitem)
    local label = compitem.label
    if label == nil then return {} end

    local inserttext = compitem.insertText
    if inserttext == nil then return {} end

    if label == inserttext then return {} end

    return { label }
  end

  function extractors.gopls(compitem)
    local lines = {}
    local need_sepline = false

    local detail = compitem.detail
    if detail then
      table.insert(lines, detail)
      need_sepline = true
    end

    local doc = compitem.documentation
    if doc ~= nil then
      if need_sepline then table.insert(lines, sepline) end
      local plain = type(doc) == "string" and doc or assert(doc.value)
      listlib.extend(lines, fn.split_iter(plain, "\n"))
      need_sepline = true
    end

    return lines
  end

  ---@diagnostic disable-next-line: unused-local
  function extractors.pyright(compitem) return {} end

  extractors.zls = extractors.gopls
end

local interpret_event
do
  local function nothing() return {}, 0, 0, 0, 0 end

  ---@param event optilsp.CompleteEvent
  ---@return string[],integer,integer,integer,integer @width,height,row,col
  function interpret_event(bufnr, event)
    -- have enough room
    local ok, compitem = pcall(dictlib.get, event, "completed_item", "user_data", "nvim", "lsp", "completion_item")
    if not ok then return nothing() end --so the event is not delivered by vim.lsp
    if compitem == nil then return nothing() end

    log.debug("%s", compitem)

    local lines
    do
      local langser
      do
        local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
        assert(#clients == 1, "suppose there is only one active langserver")
        langser = clients[1].name
      end

      local extract = extractors[langser]
      if extract == nil then
        jelly.warn("no extractor for %s", langser)
        return nothing()
      end

      lines = extract(compitem)
    end

    if #lines == 0 then return nothing() end
    local width = assert(fn.max(fn.map(function(line) return #line end, lines)))
    if width == 0 then return nothing() end

    -- add paddings
    table.insert(lines, 1, "")
    table.insert(lines, "")

    -- screen/editor level
    local row, col
    do
      local pum_row_start = event.row
      local pum_col_end = event.col + event.width
      row = pum_row_start
      col = pum_col_end + 1
    end

    -- todo: max width, wrap
    return lines, width, #lines, row, col
  end
end

---@param host_bufnr integer
---@param event optilsp.CompleteEvent
local function show_preview(host_bufnr, event)
  if not state:has_valid_buf() then state.bufnr = Ephemeral({ bufhidden = "unload", namepat = "pump://{bufnr}" }) end

  local lines, width, height, row, col = interpret_event(host_bufnr, event)
  if #lines == 0 then return end

  -- vim.schedule exists for textlock
  vim.schedule(function()
    local ok, err = pcall(api.nvim_buf_set_lines, state.bufnr, 0, -1, false, lines)
    if not ok then jelly.warn("nvim_buf_set_lines error: %s", err) end
    if state:has_valid_win() then
      api.nvim_win_set_height(state.winid, #lines)
      api.nvim_win_set_width(state.winid, width)
    else
      local winopts = { noautocmd = true, relative = "editor", width = width, height = height, row = row, col = col }
      state.winid = rifts.open.win(state.bufnr, false, winopts)
    end
  end)
end

local function hide_preview()
  if not state:has_valid_win() then return end
  api.nvim_win_close(state.winid, true)
  state.winid = nil
end

function M.init()
  M.init = nil

  local aug = Augroup("optilsp://pump")
  aug:repeats("CompleteChanged", {
    callback = function() show_preview(api.nvim_get_current_buf(), vim.v.event) end,
  })
  aug:repeats("CompleteDone", {
    callback = function()
      if vim.fn.pumvisible() == 1 then return end
      hide_preview()
    end,
  })
end

return M
