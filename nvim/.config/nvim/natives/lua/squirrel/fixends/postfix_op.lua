local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("fixends.++", "info")
local ni = require("infra.ni")
local wincursor = require("infra.wincursor")

---forms
---* x++
---* x.y++
---* x[y]++
local regex = vim.regex([[\zs[a-zA-Z0-9\[\]._]\+\ze\(++\|--\)$]])

---@param winid integer
---@return true?
return function(winid) --
  local bufnr = ni.get_current_buf()
  local cursor = wincursor.position(winid)

  local start_col, stop_col = regex:match_line(bufnr, cursor.lnum, 0, cursor.col)
  if not (start_col and stop_col) then return jelly.debug("no ++ prompt") end

  local matched = assert(buflines.partial_line(bufnr, cursor.lnum, start_col, stop_col + 2))
  local var = string.sub(matched, 1, -3)
  local operator = string.sub(matched, -1, -1)
  local fix = string.format("%s = %s %s 1", var, var, operator)

  ni.buf_set_text(bufnr, cursor.lnum, start_col, cursor.lnum, cursor.col, { fix })
  wincursor.go(winid, cursor.lnum, start_col + #fix)

  return true
end
