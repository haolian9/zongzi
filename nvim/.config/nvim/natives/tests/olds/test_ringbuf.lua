local strlib = require("infra.strlib")

local RingBuf = require("olds.RingBuf")

local function test_1()
  local ring = RingBuf(5)

  assert(ring:read() == nil)

  ring:write(1)
  assert(ring:read() == 1)
end

local function test_2()
  local ring = RingBuf(5)

  for i = 1, 5 do
    ring:write(i)
  end

  local ok, err = pcall(function() ring:write(6) end)
  assert(not ok)
  assert(strlib.endswith(err, "full"))
end

local function test_3()
  local ring = RingBuf(5)

  for i = 1, 5 do
    ring:write(i)
  end

  for i = 1, 5 do
    assert(ring:read() == i)
  end
  assert(ring:read() == nil)

  for i = 1, 5 do
    ring:write(i)
  end

  for i = 1, 5 do
    assert(ring:read() == i)
  end
  assert(ring:read() == nil)
end

local function test_4()
  local ring = RingBuf(5)

  ring:write(1)
  ring:write(2)
  ring:write(3)

  assert(ring:read() == 1)

  ring:write(4)
  ring:write(5)
  assert(ring:read() == 2)

  assert(ring:read() == 3)
  assert(ring:read() == 4)
  assert(ring:read() == 5)
  assert(ring:read() == nil)
end

test_1()
test_2()
test_3()
test_4()
