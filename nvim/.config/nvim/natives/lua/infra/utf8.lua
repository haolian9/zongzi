local M = {}

--stole from zig.unicode.utf8ByteSequenceLength
local ranges = {
  { tonumber("00000000", 2), tonumber("01111111", 2) },
  { tonumber("11000000", 2), tonumber("11011111", 2) },
  { tonumber("11100000", 2), tonumber("11101111", 2) },
  { tonumber("11110000", 2), tonumber("11110111", 2) },
}

M.maxbytes = #ranges

---@param chars string
---@param offset? number @default to 1
---@return number
function M.byte0(chars, offset) return string.byte(chars, offset or 1) end

---@param byte0 number
function M.rune_length(byte0)
  for i, range in ipairs(ranges) do
    if byte0 >= range[1] and byte0 <= range[2] then return i end
  end
  error("invalid utf8 start byte")
end

--iterate over utf8 runes
---@param chars string @chars
function M.iterate(chars)
  local offset = 1

  ---@return nil|string
  return function()
    if offset > #chars then return end

    local len = M.rune_length(M.byte0(chars, offset))
    local last = offset + len - 1
    assert(#chars >= last, "not enough bytes for a utf8 rune")

    local rune = chars:sub(offset, last)
    offset = last + 1

    return rune
  end
end

return M
