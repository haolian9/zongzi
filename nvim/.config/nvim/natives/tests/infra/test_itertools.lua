local itertools = require("infra.itertools")

-- for zip_longest
local test_0 = function()
  do
    local a = {}
    local b = { true }
    assert(#a == 0 and #b == 1)
    local iter = itertools.zip_longest(a, b)
    local x, y = unpack(iter())
    assert(x == nil and y == true)
    assert(iter() == nil)
  end
  do
    local a = { true, false, true, false }
    local b = { true, true, false }
    local iter = itertools.zip_longest(a, b)
    local x, y
    x, y = unpack(iter())
    assert(x and y)
    x, y = unpack(iter())
    assert(x == false and y)
    x, y = unpack(iter())
    assert(x and y == false)
    x, y = unpack(iter())
    assert(x == false and y == nil)
    assert(iter() == nil)
  end

  do
    local iter = itertools.zip_longest({}, { 1, 2, 3 })
    local x, y
    x, y = unpack(iter())
    assert(x == nil and y == 1)
    x, y = unpack(iter())
    assert(x == nil and y == 2)
    x, y = unpack(iter())
    assert(x == nil and y == 3)
    assert(iter() == nil)
  end
end

-- for equals
local test_1 = function()
  local feeds = {
    { { true, true, true }, { true, true, true }, true },
    { { true, true, true }, { true, false, true }, false },
    { { true, true, true }, { true, true }, false },
    { { true, true, true }, { true, nil, true }, false },
  }
  for feed in itertools.iter(feeds) do
    local a, b, expected = unpack(feed)
    assert(itertools.equals(a, b) == expected)
  end
end

-- for filter
local function test_2()
  local iter = itertools.filter({ 1, 2, 3, 4, 5 }, function(el) return el % 2 == 1 end)
  assert(itertools.equals(iter, { 1, 3, 5 }))
end

-- range, slice
local function test_3()
  do
    local iter = itertools.range(1, 5)
    assert(itertools.equals(iter, { 1, 2, 3, 4 }))
  end

  do
    local range = itertools.range(1, 5)
    assert(not pcall(itertools.slice, range, 1, 1), "start < stop")
  end

  do
    local range = itertools.range(1, 5)
    local iter = itertools.slice(range, 0, 1)
    assert(itertools.equals(iter, { 1 }))
  end

  do
    local range = itertools.range(1, 5)
    local iter = itertools.slice(range, 2, 4)
    assert(itertools.equals(iter, { 3, 4 }))
  end

  do
    local range = itertools.range(1, 5)
    local iter = itertools.slice(range, 2, 6)
    assert(itertools.equals(iter, { 3, 4 }))
  end
end

local function test_4()
  local source = function(stop)
    local count = 0
    return function()
      count = count + 1
      if count > stop then return end
      return count, count
    end
  end

  local it = itertools.mapn(source(5), function(a, b) return a + b end)

  assert(itertools.equals(it, { 2, 4, 6, 8, 10 }))
end

local function test_5()
  do
    local iter = itertools.range(5, 0, 1)
    assert(itertools.equals(iter, {}))
  end

  do
    local iter = itertools.range(0, 5, -1)
    assert(itertools.equals(iter, {}))
  end

  do
    local iter = itertools.range(5, 0, -1)
    assert(itertools.equals(iter, { 5, 4, 3, 2, 1 }))
  end

  do
    local iter = itertools.range(0, 5, 1)
    assert(itertools.equals(iter, { 0, 1, 2, 3, 4 }))
  end

  do
    local iter = itertools.range(0, 5)
    assert(itertools.equals(iter, { 0, 1, 2, 3, 4 }))
  end

  do
    local iter = itertools.range(5)
    assert(itertools.equals(iter, { 0, 1, 2, 3, 4 }))
  end
end

local function test_6()
  do
    local list = {
      { a = 1 },
      { a = 2 },
      { a = 4 },
      { a = 5 },
    }
    local iter = itertools.project(list, "a")
    assert(itertools.equals(iter, { 1, 2, 4, 5 }))
  end
  local list = {
    { a = 1 },
    { a = 2 },
    { a = nil },
    { a = 5 },
  }
  local iter = itertools.project(list, "a")
  assert(iter() == 1)
  assert(iter() == 2)
  assert(not pcall(iter))
end

local function test_7()
  local iter = itertools.enumerate({ 1, 2, 3, 4 })
  local k, v
  k, v = iter()
  assert(k == 0)
  assert(v == 1)

  k, v = iter()
  assert(k == 1)
  assert(v == 2)

  k, v = iter()
  assert(k == 2)
  assert(v == 3)

  k, v = iter()
  assert(k == 3)
  assert(v == 4)
end

test_0()
test_1()
test_2()
test_3()
test_4()
test_5()
test_6()
test_7()

-- millet: source
