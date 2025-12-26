local M = {}

local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("squirrel.veil", "info")
local mi = require("infra.mi")
local prefer = require("infra.prefer")
local resolve_line_indents = require("infra.resolve_line_indents")
local vsel = require("infra.vsel")

---@type {[string]: string[]}
local blk_pairs = {
  lua = { "do", "end" },
  zig = { "{", "}" },
  c = { "{", "}" },
  go = { "{", "}" },
  sh = { "{", "}" },
}

---@param ft string
---@param bufnr? integer
function M.cover(ft, bufnr)
  bufnr = mi.resolve_bufnr_param(bufnr)
  ft = ft or prefer.bo(bufnr, "filetype")

  local pair = blk_pairs[ft]
  if pair == nil then return jelly.warn("not supported filetype for squirrel.veil") end

  local range = vsel.range(bufnr)
  if range == nil then return jelly.info("no selection") end

  local lines
  do
    local indents, ichar, iunit = resolve_line_indents(bufnr, range.start_line)
    lines = buflines.lines(bufnr, range.start_line, range.stop_line)
    do
      local add = string.rep(ichar, iunit)
      for i = 1, #lines do
        lines[i] = add .. lines[i]
      end
    end
    do
      local add = indents
      table.insert(lines, 1, add .. pair[1])
      table.insert(lines, add .. pair[2])
    end
  end

  buflines.replaces(bufnr, range.start_line, range.stop_line, lines)
end

function M.uncover(ft, bufnr)
  local _, _ = ft, bufnr
  error("not implemented")
end

return M
