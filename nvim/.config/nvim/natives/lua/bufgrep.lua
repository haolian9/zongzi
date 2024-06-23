local M = {}

local buflines = require("infra.buflines")
local ni = require("infra.ni")
local vsel = require("infra.vsel")

local puff = require("puff")
local sting = require("sting")

---@param regex vim.Regex
---@param text_fn fun(bufnr: integer, lnum: integer, start_col: integer, stop_col: integer): string
local function main(regex, text_fn)
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local shelf = sting.location.shelf(winid, string.format("lvimgrep://%s", bufnr))

  shelf:reset()
  for lnum = 0, buflines.high(bufnr) do
    local start_col, stop_col = regex:match_line(bufnr, lnum)
    if start_col and stop_col then
      local row = lnum + 1
      shelf:append({ bufnr = bufnr, col = start_col, end_col = stop_col, lnum = row, end_lnum = row, text = text_fn(bufnr, lnum, start_col, stop_col) })
    end
  end
  shelf:feed_vim(true, false)
end

function M.vsel()
  local fixed = vsel.oneline_text()
  if fixed == nil then return end

  main( --
    vim.regex(vim.fn.escape(fixed, [[.$*~\]])),
    function() return fixed end
  )
end

---@param pattern string @very magic
function M.text(pattern)
  main( --
    vim.regex([[\v]] .. pattern),
    function(bufnr, lnum, start_col, stop_col) return assert(buflines.partial_line(bufnr, lnum, start_col, stop_col)) end
  )
end

function M.input()
  puff.input({ prompt = "lvimgrep", icon = "🔍", startinsert = "a", remember = "bufgrep" }, function(pattern)
    if pattern == nil or pattern == "" then return end
    M.text(pattern)
  end)
end

return M
