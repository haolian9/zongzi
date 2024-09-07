local jelly = require("infra.jellyfish")("fixend.general")
local ni = require("infra.ni")
local resolve_line_indents = require("infra.resolve_line_indents")
local wincursor = require("infra.wincursor")

local try_inline_pair, try_multiline_pair
do
  local inline_pairs = {
    --i prefer `''<c-o>i` muscle memory
    -- { 1, { ['"'] = '"', ["'"] = "'", ["("] = ")", ["{"] = "}", ["["] = "]", ["`"] = "`" } },
    { 2, { ["[["] = "]]" } },
    { 3, { ["'''"] = "'''", ['"""'] = '"""', ["```"] = "```" } },
  }

  local multiline_pairs = {
    { 2, { ["do"] = "end" } },
    { 4, { ["then"] = "end" } },
  }

  ---@param bufnr integer
  ---@param cursor_lnum integer
  ---@param cursor_col integer
  ---@return string?
  local function get_prompt(bufnr, cursor_lnum, cursor_col)
    if cursor_col == 0 then return jelly.debug("blank line") end
    local start_col = math.max(cursor_col - multiline_pairs[#multiline_pairs][1], 0)
    local text = ni.buf_get_text(bufnr, cursor_lnum, start_col, cursor_lnum, cursor_col, {})
    jelly.info("prompt texts: %s", text)
    local prompt = text[1]
    if prompt == "" then return end
    return prompt
  end

  ---@param store table
  ---@param prompt string
  ---@return string?
  local function find_right(store, prompt)
    for i = #store, 1, -1 do
      local len = store[i][1]
      local end_chars = string.sub(prompt, -len)
      if #end_chars == len then
        for a, b in pairs(store[i][2]) do
          if end_chars == a then return b end
        end
      end
    end
  end

  ---@param winid integer
  ---@param bufnr integer
  ---@return boolean? @nil=false=failed
  function try_inline_pair(winid, bufnr)
    local cursor = wincursor.position(winid)

    local right
    do
      local prompt = get_prompt(bufnr, cursor.lnum, cursor.col)
      if prompt == nil then return jelly.debug("no prompt") end

      right = find_right(inline_pairs, prompt)
      if right == nil then return jelly.debug("no available pair found") end

      local follows = ni.buf_get_text(bufnr, cursor.lnum, cursor.col, cursor.lnum, cursor.col + #right, {})[1]
      if follows == right then return jelly.debug("no need to add right side") end
    end

    ni.buf_set_text(bufnr, cursor.lnum, cursor.col, cursor.lnum, cursor.col, { right })
  end

  ---@param winid integer
  ---@param bufnr integer
  ---@return boolean? @nil=false=failed
  function try_multiline_pair(winid, bufnr)
    local cursor = wincursor.position(winid)

    local right
    do
      local prompt = get_prompt(bufnr, cursor.lnum, cursor.col)
      if prompt == nil then return jelly.debug("no prompt") end
      right = find_right(multiline_pairs, prompt)
      if right == nil then return jelly.debug("no available pair found") end
    end

    local fixes
    do
      local indents, ichar, iunit = resolve_line_indents(bufnr, cursor.lnum)
      fixes = { "", indents .. string.rep(ichar, iunit), indents .. right }
    end

    ni.buf_set_text(bufnr, cursor.lnum, cursor.col, cursor.lnum, cursor.col, fixes)
    wincursor.go(winid, cursor.lnum + #fixes - 1, string.len(fixes[#fixes]))
  end
end

---@param winid integer
---@return boolean? @nil=false=failed
return function(winid)
  local bufnr = ni.win_get_buf(winid)
  if try_inline_pair(winid, bufnr) then return end
  if try_multiline_pair(winid, bufnr) then return end
end
