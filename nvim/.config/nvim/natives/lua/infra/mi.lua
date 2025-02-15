---customized nvim api

local M = {}

local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local ni = require("infra.ni")

do
  local function in_expected_mode()
    local mode = ni.get_mode().mode
    local m = string.sub(mode, 1, 1)

    if m == "n" then return true end
    if m == "v" then return true end
    if m == "V" then return true end
    if m == "s" then return true end
    if m == "R" then return true end
    if mode == "CTRL-V" then return true end
    if mode == "CTRL-Vs" then return true end
    if mode == "CTRL-S" then return true end

    return false
  end

  ---@param fmt string @no need to prefix with :
  ---@param ... any
  function M.setcmdline(fmt, ...)
    if not in_expected_mode() then error("unreachable") end

    local str = string.format(fmt, ...)

    feedkeys.codes(":", "n")
    vim.schedule(function() --another vim.schedule magic
      assert(ni.get_mode().mode == "c")
      vim.fn.setcmdline(str, #str + #":") --pos in bytes
    end)
  end
end

---@param winid integer
---@return boolean
function M.win_is_float(winid) return ni.win_get_config(winid).relative ~= "" end

---@param winid integer
---@return boolean
function M.win_is_landed(winid) return ni.win_get_config(winid).relative == "" end

---@param what 'cache'|'config'|'data'|'run'|'state'
---@return string
function M.stdpath(what)
  local result = vim.fn.stdpath(what)
  assert(type(result) == "string")
  return result
end

---it places cursor right after the insertion position
---note: it's an async op
function M.stopinsert()
  if ni.get_mode().mode == "i" then
    feedkeys("<esc>l", "n")
  else
    ex("stopinsert")
  end
end

---@param bufnr integer
---@param enter boolean
---@param opts vim.api.keyset.win_config
---@return integer winid
function M.open_win(bufnr, enter, opts)
  local winid = ni.open_win(bufnr, enter, opts)

  --no sharing loclist
  vim.fn.setloclist(winid, {}, "f")

  return winid
end

return M
