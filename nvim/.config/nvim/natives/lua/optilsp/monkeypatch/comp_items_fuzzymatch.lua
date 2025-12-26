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

---stolen from lsp.completion.get_completion_word
---@return string
local function get_completion_word(item)
  if item.insertTextFormat == protocol.InsertTextFormat.Snippet then
    return item.label
  elseif item.textEdit then
    local word = item.textEdit.newText
    return word:match("^(%S*)") or word
  elseif item.insertText and item.insertText ~= "" then
    return item.insertText
  else
    return item.label
  end
end

local function is_deprecated(item)
  if item.deprecated then return true end
  if item.tags and listlib.contains(item.tags, protocol.CompletionTag.Deprecated) then return true end
  return false
end

--rewrite of vim.lsp.completion._lsp_to_complete_items
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
    --:h complete-items
    matches[i] = {
      word = word,
      kind = protocol.CompletionItemKind[compitem.kind] or "Unknown",
      abbr = nil,
      menu = nil, -- no enough room for popup menu
      info = nil, -- not enough room for preview info
      icase = 1,
      dup = 0, -- no duplicates
      empty = 0, -- no empty entry
      user_data = { nvim = { lsp = { completion_item = compitem } } },
      abbr_hlgroup = is_deprecated(compitem) and "DiagnosticDeprecated" or nil,
    }
  end

  -- table.sort(matches, function(a, b) return #a.word < #b.word end)

  return matches
end
