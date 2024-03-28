local M = {}

local Augroup = require("infra.Augroup")
local dictlib = require("infra.dictlib")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("optilsp.snip", "info")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local parrot = require("parrot")

local log = logging.newlogger("optilsp.snip", "info")

local api = vim.api

local function on_complete_done()
  local compitem
  do
    log.debug("%s", vim.v.completed_item)
    local ok, got = pcall(dictlib.get, vim.v.completed_item, "user_data", "nvim", "lsp", "completion_item")
    if not ok then return end -- not produced by lsp
    if got == nil then return end
    ---@type optilsp.CompItem
    compitem = got
    if compitem.insertText == nil then return end
    if compitem.insertTextFormat ~= 2 then return end -- the magic number of InsertTextFormat.Snippet
    --workaround of https://github.com/LuaLS/lua-language-server/issues/2312
    if strlib.find(compitem.insertText, "$") == nil then return end
  end

  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local insert_lnum, insert_col
  do
    local start_row, stop_col = unpack(api.nvim_win_get_cursor(winid))
    local start_col = stop_col - #compitem.insertText
    local ok, err = pcall(api.nvim_buf_set_text, bufnr, start_row - 1, start_col, start_row - 1, stop_col, {})
    if not ok then error(err) end

    insert_lnum = start_row - 1
    insert_col = start_col
    api.nvim_win_set_cursor(winid, { insert_lnum + 1, insert_col })
  end

  local chirps = fn.split(compitem.insertText, "\n")

  parrot.expand_external_chirps(chirps, winid, insert_lnum, insert_col, true)
end

function M.init()
  M.init = nil

  local aug = Augroup("parrot://lsp_snippet")
  aug:repeats("CompleteDone", { callback = on_complete_done })
end

return M
