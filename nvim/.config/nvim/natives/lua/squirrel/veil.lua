local M = {}

local jelly = require("infra.jellyfish")("squirrel.veil", "info")
local prefer = require("infra.prefer")
local resolve_line_indents = require("infra.resolve_line_indents")
local vsel = require("infra.vsel")

local api = vim.api

---@type {[string]: string[]}
local blk_pairs = {
  lua = { "do", "end" },
  zig = { "{", "}" },
  c = { "{", "}" },
  go = { "{", "}" },
  sh = { "{", "}" },
}

function M.cover(ft, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  ft = ft or prefer.bo(bufnr, "filetype")

  local pair = blk_pairs[ft]
  if pair == nil then return jelly.warn("not supported filetype for squirrel.veil") end

  local range = vsel.range(bufnr)
  if range == nil then return jelly.info("no selection") end

  local lines
  do
    local indents, ichar, iunit = resolve_line_indents(bufnr, range.start_line)
    lines = api.nvim_buf_get_lines(bufnr, range.start_line, range.stop_line, false)
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

  api.nvim_buf_set_lines(bufnr, range.start_line, range.stop_line, false, lines)
end

function M.uncover(ft, bufnr)
  local _, _ = ft, bufnr
  error("not implemented")
end

return M
