local listlib = require("infra.listlib")

local api = vim.api
local lsp = vim.lsp
local lsputil = vim.lsp.util

local compitem_matcher = require("optilsp.omnifunc.compitem_matcher")

local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char
  for _, item in ipairs(items) do
    if item.filterText == nil and item.textEdit and item.textEdit.range.start.line == lnum - 1 then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then return end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then return lsputil._str_byteindex_enc(line, min_start_char, encoding) end
end

-- stole from vim.lsp.omnifunc
return function(findstart, base)
  local _ = base

  local bufnr = api.nvim_get_current_buf()
  if #vim.lsp.get_active_clients({ bufnr = bufnr }) < 1 then return findstart == 1 and -1 or {} end

  local cursor = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()

  local matched = vim.fn.match(line:sub(1, cursor[2]), "\\k*$")

  local params = lsputil.make_position_params()

  local items = {}
  lsp.buf_request(bufnr, "textDocument/completion", params, function(err, result, ctx)
    if err ~= nil then error(err) end
    if result == nil then return end
    if api.nvim_get_mode().mode ~= "i" then return end

    local startbyte, matches
    do
      local client = lsp.get_client_by_id(ctx.client_id)
      local encoding = client and client.offset_encoding or "utf-16"
      local candidates = lsputil.extract_completion_items(result)
      startbyte = adjust_start_col(cursor[1], line, candidates, encoding) or matched
      local prefix = line:sub(startbyte + 1, cursor[2])
      matches = compitem_matcher(nil, prefix, candidates)
    end

    listlib.extend(items, matches)

    vim.fn.complete(startbyte + 1, items)
  end)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end
