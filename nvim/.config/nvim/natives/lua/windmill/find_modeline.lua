local api = vim.api
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("windmill.modeline", "info")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local find_millet_cmd
do
  ---@param bufnr number
  ---@return string?
  local function resolve_millet_prefix(bufnr)
    local pattern = prefer.bo(bufnr, "commentstring")
    if pattern == "" then return jelly.debug("no &commentstring") end
    return string.format(pattern, "millet: ")
  end

  ---@param bufnr number
  ---@param max number
  local function reversed_lines(bufnr, max)
    local total = api.nvim_buf_line_count(bufnr)
    local start = total
    local stop = start - max
    return function()
      start = start - 1
      if start >= stop then return api.nvim_buf_get_lines(bufnr, start, start + 1, true)[1] end
    end
  end

  function find_millet_cmd(bufnr)
    local prefix = resolve_millet_prefix(bufnr)
    if prefix == nil then return end

    local modelines = prefer.bo(bufnr, "modelines")
    for line in reversed_lines(bufnr, modelines) do
      if strlib.startswith(line, prefix) then return string.sub(line, #prefix + 1) end
    end
    jelly.debug("found no millets in last %d line", modelines)
  end
end

---for example: // millet: sh %:p
---respect: 'commentstring', 'modelines'
---placeholder: %:p
---@param bufnr integer
---@param fpath string @aka, '%:p'
---@return nil|string[]
return function(bufnr, fpath)
  local parts
  do
    local str = find_millet_cmd(bufnr)
    if str == nil then return end
    parts = fn.split(str, " ")
  end

  do -- inject/replace fpath
    local placeholder_index
    for i = #parts, 1, -1 do
      local val = parts[i]
      -- only expect one file placeholder
      if val == "%:p" then
        placeholder_index = i
        break
      end
    end
    if placeholder_index == nil then
      table.insert(parts, fpath)
    else
      parts[placeholder_index] = fpath
    end
  end

  return parts
end
