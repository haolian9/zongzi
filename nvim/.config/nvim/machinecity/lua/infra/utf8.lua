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
---@param offset ?number @default to 1
---@return number
M.byte0 = function(chars, offset)
  return string.byte(chars, offset or 1)
end

---@param byte0 number
M.rune_length = function(byte0)
  for i, range in pairs(ranges) do
    if byte0 >= range[1] and byte0 <= range[2] then return i end
  end
  error("invalid utf8 start byte")
end

-- iterate over utf8 runes
---@param chars string @chars
M.iterate = function(chars)
  local offset = 1

  ---@return nil|string
  return function()
    if offset > #chars then return end

    local _len = M.rune_length(M.byte0(chars, offset))

    local _end = offset + _len - 1
    assert(#chars >= _end, "not enough bytes for a utf8 rune")

    local rune = chars:sub(offset, _end)
    offset = _end + 1

    return rune
  end
end

M.test = function()
  local function test_0()
    local feeds = {
      { "h", 1 },
      { "你", 3 },
    }
    for _, el in pairs(feeds) do
      local rune, len = unpack(el)
      local byte0 = string.byte(rune, 1, 1)
      assert(M.rune_length(byte0) == len)
    end
  end

  local function test_1()
    local iter = M.iterate("h 你好-. ")
    assert(iter() == "h")
    assert(iter() == " ")
    assert(iter() == "你")
    assert(iter() == "好")
    assert(iter() == "-")
    assert(iter() == ".")
    assert(iter() == " ")
    assert(iter() == nil)
  end

  test_0()
  test_1()
end

return M
