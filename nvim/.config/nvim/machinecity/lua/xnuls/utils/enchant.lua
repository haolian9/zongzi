-- for completion enchantment text used by null-ls
--
-- params:
-- * word_to_complete: str,
-- * content: nil,
-- * cursor_line: str,
-- * bufname: str,
-- * bufnr: int,
-- * client_id: int
-- * col: int, row: int,
-- * ft: str
-- * lsp_method: str
-- * method: str; NULL_LS_COMPLETION

local M = {}

local jelly = require("infra.jellyfish")("nuls.enchant")

M.lua_spell_of_require = function(params)
  -- not multi-line
  -- supported forms:
  -- * require'', require"", require[[]]
  -- * require(''), require(""), require([[]])
  local line = assert(params.cursor_line)

  local start, stop = string.find(line, "require")
  if start == nil then return end

  local spell_start
  do
    local rest = string.sub(line, stop + 1)
    local quote
    local rest_stop
    for i = 1, #rest do
      local code = string.byte(rest, i)
      if code == 0x20 then
      -- spcace
      elseif code == 0x28 then
      -- (
      elseif code == 0x22 then
        -- "
        quote = [[']]
        rest_stop = i + 1
        break
      elseif code == 0x27 then
        -- '
        quote = [["]]
        rest_stop = i + 1
        break
      elseif code == 0x5b then
        -- [
        quote = "[["
        if string.byte(rest, i + 1) ~= 0x5b then
          jelly.debug("not a valid [[ quote: %s", rest)
          return
        end
        rest_stop = i + 2
        break
      else
        jelly.debug("not a valid require call: %s", rest)
        return
      end
    end
    if quote == nil then
      jelly.debug("no quote string found: %s", rest)
      return
    end
    spell_start = stop + rest_stop
  end

  local spell = string.sub(line, spell_start, params.col)
  if spell == "" then return end
  return spell
end

---@param params table
M.lua_spell = function(params)
  -- pattern
  -- * word=[a-zA-Z0-9._]
  -- * word(.word){0,}
  local function valid_char(code)
    if code >= 0x30 and code <= 0x39 then
      -- 0-9
      return true
    end
    if code >= 0x41 and code <= 0x5a then
      -- A-Z
      return true
    end
    if code >= 0x61 and code <= 0x7a then
      -- a-z
      return true
    end
    if code == 0x5f then
      -- _
      return true
    end
    if code == 0x2e then
      -- .
      return true
    end
    return false
  end

  local line = assert(params.cursor_line)

  local spell_start = 1
  local spell_stop = params.col
  do
    for i = spell_stop, 1, -1 do
      local code = string.byte(line, i)
      if valid_char(code) then
        spell_start = i
      elseif code == 0x20 then
        -- space
        break
      else
        jelly.debug("unpexpected char code: %d at %d", code, i)
        break
      end
    end
  end

  local spell = string.sub(line, spell_start, spell_stop)
  if spell == "" then return end
  return spell
end

return M
