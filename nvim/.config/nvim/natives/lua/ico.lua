local ascii = require("infra.ascii")
local mi = require("infra.mi")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("ico", "debug")
local tty = require("infra.tty")

local function is_inputable(code)
  if code >= ascii.space and code <= ascii.tilde then return true end
  if code == ascii.tab then return true end
  return false
end

---@param mode 'f'|'t'
local function ft(mode)
  local char, code = tty.read_raw()
  if not is_inputable(code) then return jelly.warn("unexpected (%s, %d) for %schar", char, code, mode) end
  feedkeys.codes(mode, "n")
  feedkeys.keys(char, "m")
  feedkeys.codes("a", "n")
end

---designed to replace i_ctrl-o
return function()
  mi.stopinsert()

  vim.schedule(function() --schedule to allow redrawing the cursor
    local char, code = tty.read_raw()
    if code == ascii.esc then return end

    if code == ascii.t then return ft("t") end
    if code == ascii.f then return ft("f") end

    --behave like the original <c-o>
    feedkeys.keys("i<c-o>", "n")
    feedkeys.keys(char, "m")
  end)
end
