local jelly = require("infra.jellyfish")("squirrel.fstr")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

local nuts = require("squirrel.nuts")

---@return TSNode?
local function find_str_at_cursor(winid)
  ---@type TSNode?
  local node = nuts.get_node_at_cursor(winid)
  for _ = 1, 5 do
    if node == nil then break end
    if node:type() == "string" then return node end
    node = node:parent()
  end
  return jelly.warn("no string around")
end

--supported cases: "|", |"", ""|
--
--design choices:
--* for python buffers of course
--* relying on treesitter
--* no cursor movement
return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  assert(prefer.bo(bufnr, "filetype") == "python")

  local str_node = find_str_at_cursor(winid)
  if str_node == nil then return end

  local start_char = nuts.get_node_first_char(bufnr, str_node)
  local start_line, start_col = str_node:start()

  if start_char == "f" then
    ni.buf_set_text(bufnr, start_line, start_col, start_line, start_col + 1, { "" })
  else
    ni.buf_set_text(bufnr, start_line, start_col, start_line, start_col, { "f" })
  end
end
