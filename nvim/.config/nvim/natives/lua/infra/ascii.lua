local M = {
  tab = 0x09,
  cr = 0x0d,
  esc = 0x1b,
  space = 0x20,
  --
  exclam = 0x21, -- !
  --
  A = string.byte("A"),
  T = string.byte("T"),
  F = string.byte("F"),
  Z = string.byte("Z"),
  --
  a = string.byte("a"),
  t = string.byte("t"),
  f = string.byte("f"),
  z = string.byte("z"),
  --
  tilde = 0x7e, -- ~
}

---@param char string
---@return boolean
function M.is_letter(char)
  local code = string.byte(char)
  return (code >= M.A and code <= M.Z) or (code >= M.a and code <= M.z)
end

return M
