local colspliter = require("furrow.colspliter")

local function test_1()
  local s = "    hello   world  yah x y "

  local spliter = colspliter(s, [[\s+]])

  assert(spliter.next() == "hello")
  assert(spliter.next() == "world")
  assert(spliter.rest() == "yah x y ")
  assert(spliter.rest() == nil)
end

local function test_3()
  local s = "    hello   world  yah x y "

  local spliter = colspliter(s, [[\s+]])

  assert(spliter.next() == "hello")
  assert(spliter.next() == "world")
  assert(spliter.next() == "yah")
  assert(spliter.next() == "x")
  assert(spliter.next() == "y")
  assert(spliter.rest() == nil)
end

test_1()
test_3()
