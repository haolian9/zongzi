local M = {}

local bufpath = require("infra.bufpath")
local coreutils = require("infra.coreutils")
local ex = require("infra.ex")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("wiki.rhs")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")
local wincursor = require("infra.wincursor")

local function resolve_link_parts()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local text
  do
    local line = ni.get_current_line()
    -- -1 for 0-based, 2 for len([[,]])
    local deviation = -1 + 2

    -- 1-based
    local col1 = wincursor.col(winid) + 1

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
    if strlib.endswith(text, "/") then return jelly.warn("trailing slash in link: %s", text) end
  end

  do
    local full_text = string.format("%s%s", text, prefer.bo(bufnr, "suffixesadd"))
    local sep_at = strlib.rfind(full_text, "/")
    if sep_at == nil then return nil, full_text end
    local parent = string.sub(full_text, 1, sep_at - 1)
    local child = string.sub(full_text, sep_at + 1)

    return parent, child
  end
end

function M.edit_link()
  -- * [[link_path/link_file]]
  -- * [[link_file]]

  local root, fpath
  do
    local dirname, fname = resolve_link_parts()
    if fname == nil then return end

    local basedir = assert(bufpath.dir(ni.get_current_buf()))

    root = basedir
    if dirname ~= nil then root = fs.joinpath(basedir, dirname) end

    fpath = fs.joinpath(root, fname)
  end

  assert(coreutils.mkdir(root))
  ex("edit", fpath)
end

return M

