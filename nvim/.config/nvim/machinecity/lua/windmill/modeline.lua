-- specs:
-- * inlinecmd_magic: prefix(&commentstring) .. " asyncrun: "
--

local M = {}

local api = vim.api
local fn = require("infra.fn")

local facts = {
  modelines = vim.go.modelines,
}

---@param cms string @comment string
---@return string?
local function inlinecmd_prefix(cms)
  local pos = string.find(cms, "%%s")
  if pos == nil then return end

  local raw = string.sub(cms, 0, pos - 1)
  local ret = string.gsub(raw, "%s+", "")

  if ret == "" then return end

  return ret
end

---@param bufnr number?
---@return string?
local function dynamic_inlinecmd_magic(bufnr)
  local prefix = inlinecmd_prefix(api.nvim_buf_get_option(bufnr, "commentstring"))

  return prefix .. " asyncrun: "
end

local find_inlinecmd = function(bufnr)
  local _reversed_lines = function()
    local total = api.nvim_buf_line_count(bufnr)
    local high = total - facts.modelines
    local start = total
    return function()
      -- high, high+1 -> 0, 1
      start = start - 1
      if start >= 0 then
        local lines = api.nvim_buf_get_lines(bufnr, start, start + 1, true)
        return lines[1]
      end
    end
  end

  local _find = function(line, magic)
    local pos = string.find(line, magic)
    if pos ~= nil then return string.sub(line, pos + string.len(magic)) end
  end

  local magic = dynamic_inlinecmd_magic(bufnr)

  for line in _reversed_lines() do
    local cmd = _find(line, magic)
    if cmd ~= nil then return cmd end
  end
end

M.inlinecmd_prefix = inlinecmd_prefix

function M.runas(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local parts
  do
    local str = find_inlinecmd(bufnr)
    if str == nil then return end
    parts = fn.split(str, " ")
  end

  do
    local fpath = vim.fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":p")
    local has_path = false
    for i = #parts, 1, -1 do
      local val = parts[i]
      -- only expect one file placeholder
      if val == "%:p" or val == "%" then
        parts[i] = fpath
        has_path = true
        break
      end
    end
    if not has_path then table.insert(parts, fpath) end
  end

  return parts
end

return M
