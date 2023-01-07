-- a rework of nvim.lsp.util.text_document_completion_list_to_complete_items

local protocol = vim.lsp.protocol
local lsputil = vim.lsp.util

local fuzzy = require("optilsp.fuzzy")
local fn = require("infra.fn")

local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.textEdit.newText
    else
      return lsputil.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return lsputil.parse_snippet(item.insertText)
    end
  end
  return item.label
end

-- rewrite of vim.lsp.util.text_document_completion_list_to_complete_items
---@param compitems table @extracted compitems from result
local function main(result, prefix, compitems)
  -- * [x] case-insensitive
  -- * [x] simple fuzzy
  -- * [x] sort by #word

  if result == nil and compitems == nil then error("either result or comitems should be given") end
  compitems = compitems or lsputil.extract_completion_items(result)
  if #compitems == 0 then return {} end

  local item_iter
  do
    local prefix_lower = string.lower(prefix)
    item_iter = fn.filter(function(item)
      local word = get_completion_word(item)
      -- sadly, pum does not support fuzzy matching!
      return fuzzy.match_lower(string.lower(word), prefix_lower)
    end, compitems)
  end
  local matches = {}
  for completion_item in item_iter do
    local word = get_completion_word(completion_item)
    table.insert(matches, {
      word = word,
      kind = lsputil._get_completion_item_kind_name(completion_item.kind),
      abbr = "", -- useless abbr
      menu = "", -- no enough room for menu
      info = "", -- not enough room for info
      icase = 1,
      dup = 0, -- no duplicates
      empty = 0, -- no empty entry
      user_data = { nvim = { lsp = { completion_item = completion_item } } },
    })
  end

  -- todo: sort by length + score
  table.sort(matches, function(a, b)
    return #a.word < #b.word
  end)

  return matches
end

return main
