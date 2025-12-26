local M = {}

local listlib = require("infra.listlib")
local strlib = require("infra.strlib")

---@alias Extractor fun(compitem: optilsp.CompItem): string[]

--todo: respect documentation.kind
--todo: line overflow
--todo: labelDetails: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemLabelDetails

local sepline = "-----"

function M.clangd(compitem)
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
    listlib.extend(lines, strlib.iter_splits(plain, "\n"))
    need_sepline = true
  end

  return lines
end

function M.luals(compitem)
  local label = compitem.label
  if label == nil then return {} end

  local inserttext = compitem.insertText
  if inserttext == nil then return {} end

  if label == inserttext then return {} end

  return { label }
end

function M.gopls(compitem)
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
    listlib.extend(lines, strlib.iter_splits(plain, "\n"))
    need_sepline = true
  end

  return lines
end

---@diagnostic disable-next-line: unused-local
function M.pyright(compitem) return {} end

function M.zls(compitem)
  local lines = {}
  local need_sepline = false

  local detail = compitem.detail
  if detail then
    listlib.extend(lines, strlib.splits(detail, "\n"))
    need_sepline = true
  end

  local doc = compitem.documentation
  if doc ~= nil then
    if need_sepline then table.insert(lines, sepline) end
    local plain = type(doc) == "string" and doc or assert(doc.value)
    listlib.extend(lines, strlib.iter_splits(plain, "\n"))
    need_sepline = true
  end

  return lines
end

return M
