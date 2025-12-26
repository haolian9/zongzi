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
---@param soffset? number
---@return number
function M.byte0(chars, soffset)
  soffset = soffset or 1
  return string.byte(chars, soffset)
end

---@param byte0 integer
---@return boolean
function M.is_valid_byte0(byte0)
  for _, range in ipairs(ranges) do
    if byte0 >= range[1] and byte0 <= range[2] then return true end
  end
  return false
end

---@param byte0 integer
function M.rune_length(byte0)
  for i, range in ipairs(ranges) do
    if byte0 >= range[1] and byte0 <= range[2] then return i end
  end
  error("invalid utf8 start byte")
end

--iterate over utf8 runes
---@param soffset? integer
---@param chars string @chars
---@param tolerant? boolean @nil=false
function M.iterate(chars, soffset, tolerant)
  if tolerant == nil then tolerant = false end
  soffset = soffset or 1

  ---@return nil|string
  return function()
    if soffset > #chars then return end

    local len = M.rune_length(M.byte0(chars, soffset))
    local last = soffset + len - 1

    if #chars < last then
      if tolerant then return end
      error("not enough byts for a utf8 rune")
    end

    local rune = chars:sub(soffset, last)
    soffset = last + 1

    return rune
  end
end

return M
