-- visual select relevant functions
--
-- special position of <>
-- * nil       (0, 0; 0, 0)
-- * top-left: (1, 0; 1, 0)
-- * $
--
-- row: 1-based
-- col: 0-based

local M = {}

local utf8 = require("infra.utf8")
local nvimkeys = require("infra.nvimkeys")

local api = vim.api

-- MAX_COL
M.dollar = math.pow(2, 31) - 1

--returns start{row,col},stop{row,col}
--* row is 1-based
--* col is 0-based
---@param bufnr number
---@return number,number,number,number
function M.range(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local start_row, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
  -- NB: `>` mark returns the position of first byte of multi-bytes rune
  local stop_row, stop_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))

  return start_row, start_col, stop_row, stop_col
end

-- only support one line select
---@param bufnr ?number
---@return nil|string
function M.oneline_text(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local start_row, start_col, stop_row, stop_col = M.range(bufnr)

  if start_row ~= stop_row then return end

  -- fresh start, no select
  if start_row == 0 and start_col == 0 and stop_row == 0 and stop_col == 0 then return end

  -- shortcut
  if stop_col == M.dollar then
    -- -1 for 0-based
    local row = start_row - 1
    local lines = api.nvim_buf_get_text(bufnr, row, start_col, row, -1, {})
    return lines[1]
  end

  local chars
  do
    -- -1 for 0-based
    local row = start_row - 1
    -- 1 for exclusive
    local _stop_col = stop_col + 1 + utf8.maxbytes
    local lines = api.nvim_buf_get_text(bufnr, row, start_col, row, _stop_col, {})
    chars = lines[1]
  end

  local text
  do
    local sel_len = stop_col - (start_col - 1)
    -- multi-bytes utf-8 rune
    local byte0 = utf8.byte0(chars, sel_len)
    local rune_len = utf8.rune_length(byte0)
    text = chars:sub(1, sel_len + rune_len - 1)
  end
  return text
end

-- according to `:h magic`
---@param bufnr ?number
---@return nil|string
function M.oneline_escaped(bufnr)
  local raw = M.oneline_text(bufnr)
  if raw == nil then return end
  return vim.fn.escape(raw, [[.*~$/()]])
end

---@param bufnr ?number
---@return table|nil
function M.multiline_text(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- todo: use fn.line('v'), fn.line('.') instead
  local start_row, start_col, stop_row, stop_col = M.range(bufnr)

  if start_row == 0 and start_col == 0 and stop_row == 0 and stop_col == 0 then return end

  -- shortcut
  if stop_col == M.dollar then
    -- -1 for 0-based
    return api.nvim_buf_get_text(bufnr, start_row - 1, start_col, stop_row - 1, -1, {})
  end

  local lines
  do
    -- 1 for exclusive
    local _stop_col = stop_col + 1 + utf8.maxbytes
    lines = api.nvim_buf_get_text(bufnr, start_row - 1, start_col, stop_row - 1, _stop_col, {})
  end

  -- handles last line
  do
    local chars = lines[#lines]
    local sel_len
    if stop_row > start_row then
      sel_len = stop_col + 1
    else
      sel_len = stop_col - (start_col - 1)
    end
    -- multi-bytes utf-8 rune
    local byte0 = utf8.byte0(chars, sel_len)
    local rune_len = utf8.rune_length(byte0)
    lines[#lines] = chars:sub(1, sel_len + rune_len - 1)
  end

  return lines
end

-- the vmap version *
function M.search_forward()
  local text = M.oneline_escaped()
  if text == "" then return end

  vim.fn.setreg([[/]], text)
  api.nvim_feedkeys(nvimkeys([[/<cr>]]), "n", false)
end

-- the vmap version #
function M.search_backward()
  local text = M.oneline_escaped()
  if text == nil then return end

  vim.fn.setreg([[/]], text)
  api.nvim_feedkeys(nvimkeys([[?<cr>]]), "n", false)
end

-- the vmap version :s
function M.substitute()
  local text = M.oneline_escaped()
  if text == nil then return end

  vim.fn.setreg([["]], text)
  api.nvim_feedkeys(nvimkeys([[:%s/<c-r>"/]]), "n", false)
end

return M
