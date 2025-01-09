local M = {}

local lsputil = require("vim.lsp.util")

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("optilsp.snip", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")
local wincursor = require("infra.wincursor")

local parrot = require("parrot")

local expand_snip
do
  ---@param inserted string
  ---@return true
  local function main(inserted)
    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)
    local cursor = wincursor.position(winid)

    local chirp
    do
      local normalized
      if prefer.bo(bufnr, "expandtab") then
        local tab = string.rep(" ", prefer.bo(bufnr, "tabstop"))
        normalized = string.gsub(inserted, "\t", tab)
      else
        normalized = inserted
      end
      assert(normalized)
      chirp = strlib.splits(normalized, "\n")
    end

    local insert_col = cursor.col - #inserted

    parrot.external_expand(chirp, winid, { lnum = cursor.lnum, col = insert_col, col_end = cursor.col })

    return true
  end

  ---@param compitem optilsp.CompItem
  ---@return string?
  local function try_inserttext(compitem)
    if compitem.insertText == nil then return jelly.debug("no insertText") end
    if compitem.insertTextFormat ~= 2 then return jelly.debug("not a snippet textedit") end -- the magic number of InsertTextFormat.Snippet
    --workaround of https://github.com/LuaLS/lua-language-server/issues/2312
    if not strlib.contains(compitem.insertText, "$") then return jelly.debug("has no $ sign") end

    return compitem.insertText
  end

  ---@param compitem optilsp.CompItem
  ---@return string?
  local function try_textedit(compitem)
    if compitem.textEdit == nil then return jelly.debug("no textEdit") end
    if compitem.insertTextFormat ~= 2 then return jelly.debug("not a snippet textedit") end -- the magic number of InsertTextFormat.Snippet
    --workaround of https://github.com/LuaLS/lua-language-server/issues/2312
    if not strlib.contains(compitem.textEdit.newText, "$") then return jelly.debug("has no $ sign") end

    return compitem.textEdit.newText
  end

  ---@param compitem optilsp.CompItem
  ---@return true? @if did expanded a snip
  function expand_snip(compitem)
    local inserted = try_inserttext(compitem) or try_textedit(compitem)
    if inserted == nil then return end

    main(inserted)
  end
end

---@param compitem optilsp.CompItem
local function honor_additionaltextedits(compitem)
  local edits = compitem.additionalTextEdits
  if edits == nil then return end

  --todo: not all langser speak in utf-16
  lsputil.apply_text_edits(edits, ni.get_current_buf(), "utf-16")
end

local function on_complete_done()
  ---@type optilsp.CompItem?
  local compitem = dictlib.get(vim.v.completed_item, "user_data", "nvim", "lsp", "completion_item")
  if compitem == nil then return end -- not produced by lsp

  expand_snip(compitem)

  honor_additionaltextedits(compitem)
end

function M.init()
  M.init = nil

  local aug = augroups.Augroup("parrot://lsp_snippet")
  aug:repeats("CompleteDone", { callback = on_complete_done })
end

return M
