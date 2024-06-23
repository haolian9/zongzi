local lspsnip = require("vim.lsp._snippet_grammar")

local fuzzymatch = require("beckon.fuzzymatch")

local protocol = vim.lsp.protocol

---stolen from lsp._completion.get_items
local function extract_compitems(result)
  if result.items then
    return result.items
  else
    return result
  end
end

---stolen from lsp._completion.get_completion_word
---@return string
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.textEdit.newText
    else
      return lspsnip.parse(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return lspsnip.parse(item.insertText)
    end
  end
  return item.label
end

--rewrite of vim.lsp._completion._lsp_to_complete_items
return function(result, prefix)
  ---* [x] case-insensitive
  ---* [x] fuzzy
  ---* [x] sort by #word or rank

  --sadly, pum does not support fuzzy matching!

  local compitems
  do
    compitems = extract_compitems(result)
    if #compitems == 0 then return {} end
    compitems = fuzzymatch(compitems, string.lower(prefix), { tostr = get_completion_word, sort = "asc" })
  end

  local matches = {}
  for i, compitem in ipairs(compitems) do
    local word = get_completion_word(compitem)
    matches[i] = {
      word = word,
      kind = protocol.CompletionItemKind[compitem.kind] or "Unknown",
      abbr = "", -- useless abbr
      --todo: use completeopt=popup instead
      menu = "", -- no enough room for menu
      info = "", -- not enough room for info
      icase = 1,
      dup = 0, -- no duplicates
      empty = 0, -- no empty entry
      user_data = { nvim = { lsp = { completion_item = compitem } } },
    }
  end

  -- table.sort(matches, function(a, b) return #a.word < #b.word end)

  return matches
end
