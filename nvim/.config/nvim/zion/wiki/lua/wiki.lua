-- why: i recently faced obvious lagging when use vimwiki
--
-- spec:
-- * link: [[parent/file]], [[file]]
-- * that's all
-- * no syntax, no highlight, no autocmd, no ftplugin
--

local M = {}

local api = vim.api
local coreutils = require("infra.coreutils")
local strlib = require("infra.strlib")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("wiki")

local function resolve_link_parts()
  local text
  do
    local win_id = api.nvim_get_current_win()
    local line = api.nvim_get_current_line()
    -- -1 for 0-based, 2 for len([[,]])
    local deviation = -1 + 2

    -- 1-based
    local col1 = api.nvim_win_get_cursor(win_id)[2] + 1

    local left_at
    do
      local found
      for i = col1 + deviation, 1, -1 do
        local substr = string.sub(line, i - 1, i)
        if substr == "[[" then
          found = i
          break
        end
      end
      if found == nil then return jelly.warn("no [[ found in link") end
      left_at = found + 1
    end

    local right_at
    do
      local found
      for i = col1 - deviation, #line do
        local substr = string.sub(line, i, i + 1)
        if substr == "]]" then
          found = i
          break
        end
      end
      if found == nil then return jelly.warn("no ]] found in link") end
      right_at = found - 1
    end

    text = string.sub(line, left_at, right_at)
    if vim.endswith(text, "/") then return jelly.warn("trailing slash in link: %s", text) end
  end

  do
    local full_text = string.format("%s%s", text, vim.o.suffixesadd)
    local sep_at = strlib.rfind(full_text, fs.sep)
    if sep_at == nil then return nil, full_text end
    local parent = string.sub(full_text, 1, sep_at - 1)
    local child = string.sub(full_text, sep_at + 1)

    return parent, child
  end
end

function M.edit_link()
  -- root=expand('%:p:h')
  -- * [[link_path/link_file]]
  -- * [[link_file]]

  local root = vim.fn.expand("%:p:h")
  local parent_base, child_base = resolve_link_parts()
  if child_base == nil then return end

  local parent
  if parent_base ~= nil then
    parent = fs.joinpath(root, parent_base)
    assert(coreutils.mkdir(parent))
  end
  coreutils.relative_touch(child_base, parent or root, "edit")
end

return M
