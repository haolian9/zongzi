local M = require("infra.utf8")

local function test_0()
  local feeds = {
    { "h", 1 },
    { "你", 3 },
  }
  for _, el in ipairs(feeds) do
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

local function test_2()
  -- stole from uga-rosa/utf8.nvim/lua/utf8_spec.lua
  local iter = M.iterate("こんにちは")
  assert(iter() == "こ")
  assert(iter() == "ん")
  assert(iter() == "に")
  assert(iter() == "ち")
  assert(iter() == "は")
  assert(iter() == nil)
end

test_0()
test_1()
test_2()
