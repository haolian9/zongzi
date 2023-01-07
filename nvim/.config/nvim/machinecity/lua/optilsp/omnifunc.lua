local lsp = vim.lsp
local log = require("vim.lsp.log")
local api = vim.api
local util = vim.lsp.util

local compitem_matcher = require("optilsp.compitem_matcher")

local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.filterText == nil and item.textEdit and item.textEdit.range.start.line == lnum - 1 then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then return nil end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    return util._str_byteindex_enc(line, min_start_char, encoding)
  else
    return nil
  end
end

-- stole from vim.lsp.omnifunc
local function main(findstart, base)
  local _ = log.debug() and log.debug("omnifunc.findstart", { findstart = findstart, base = base })

  local bufnr = api.nvim_get_current_buf()
  local has_buffer_clients = #vim.lsp.get_active_clients({ bufnr = bufnr }) > 0
  if not has_buffer_clients then
    if findstart == 1 then
      return -1
    else
      return {}
    end
  end

  -- Then, perform standard completion request
  local _ = log.info() and log.info("base ", base)

  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  local _ = log.trace() and log.trace("omnifunc.line", pos, line)

  -- Get the start position of the current keyword
  local textMatch = vim.fn.match(line_to_cursor, "\\k*$")

  local params = util.make_position_params()

  local items = {}
  -- todo: reuse handlers
  lsp.buf_request(bufnr, "textDocument/completion", params, function(err, result, ctx)
    if err or not result then return end

    local client = lsp.get_client_by_id(ctx.client_id)
    local encoding = client and client.offset_encoding or "utf-16"
    local candidates = util.extract_completion_items(result)
    local startbyte = adjust_start_col(pos[1], line, candidates, encoding) or textMatch
    local prefix = line:sub(startbyte + 1, pos[2])
    local matches = compitem_matcher(nil, prefix, candidates)

    vim.list_extend(items, matches)

    if vim.fn.mode() ~= "i" then return end

    vim.fn.complete(startbyte + 1, items)
  end)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

return main
