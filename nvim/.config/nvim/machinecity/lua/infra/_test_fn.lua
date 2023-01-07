local M = require("infra.fn")

-- for zip_longest
local test_0 = function()
  do
    local a = {}
    local b = { true }
    assert(#a == 0 and #b == 1)
    local iter = M.zip_longest(a, b)
    local x, y = unpack(iter())
    assert(x == nil and y == true)
    assert(iter() == nil)
  end
  do
    local a = { true, false, true, false }
    local b = { true, true, false }
    local iter = M.zip_longest(a, b)
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
    local iter = M.zip_longest({}, { 1, 2, 3 })
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

-- for split
local test_1 = function()
  local feeds = {
    { "a:b:c:d", 0, { "a:b:c:d" } },
    { "a:b:c:d", 1, { "a", "b:c:d" } },
    { "a:b:c:d", 2, { "a", "b", "c:d" } },
    { "a:b:c:d", 3, { "a", "b", "c", "d" } },
    { "a:b:c:d", 4, { "a", "b", "c", "d" } },
  }

  for feed in M.list_iter(feeds) do
    local str, maxsplit, expected = unpack(feed)
    local splits = M.split(str, ":", maxsplit)
    assert(M.iter_equals(splits, expected), string.format("%s maxsplit=%d", str, maxsplit))
  end
end

-- for split(keepends)
local test_2 = function()
  local feeds = {
    { "a:b:c:d", 0, { "a:b:c:d" } },
    { "a:b:c:d", 1, { "a:", "b:c:d" } },
    { "a:b:c:d", 2, { "a:", "b:", "c:d" } },
    { "a:b:c:d", 3, { "a:", "b:", "c:", "d" } },
    { "a:b:c:d", 4, { "a:", "b:", "c:", "d" } },
  }

  for feed in M.list_iter(feeds) do
    local str, maxsplit, expected = unpack(feed)
    local splits = M.split(str, ":", maxsplit, true)
    assert(M.iter_equals(splits, expected))
  end
end

-- for iter_equals
local test_3 = function()
  local feeds = {
    { { true, true, true }, { true, true, true }, true },
    { { true, true, true }, { true, false, true }, false },
    { { true, true, true }, { true, true }, false },
    { { true, true, true }, { true, nil, true }, false },
  }
  for feed in M.list_iter(feeds) do
    local a, b, expected = unpack(feed)
    assert(M.iter_equals(a, b) == expected)
  end
end

-- for filter
local function test_5()
  local iter = M.filter(function(el)
    return el % 2 == 1
  end, { 1, 2, 3, 4, 5 })
  assert(M.iter_equals(iter, { 1, 3, 5 }))
end

-- range, slice
local function test_6()
  do
    local iter = M.range(1, 5)
    assert(M.iter_equals(iter, { 1, 2, 3, 4 }))
  end

  do
    local range = M.range(1, 5)
    local iter = M.slice(range, 1, 1)
    assert(M.iter_equals(iter, { 1 }))
  end

  do
    local range = M.range(1, 5)
    local iter = M.slice(range, 1, 2)
    assert(M.iter_equals(iter, { 1, 2 }))
  end

  do
    local range = M.range(1, 5)
    local iter = M.slice(range, 2, 4)
    assert(M.iter_equals(iter, { 2, 3, 4 }))
  end

  do
    local range = M.range(1, 5)
    local iter = M.slice(range, 2, 6)
    assert(M.iter_equals(iter, { 2, 3, 4 }))
  end
end

local function test_7()
  local feeds = {
    { "a.b.c", ".", { "a", "b", "c" } },
    { "a%b%c", "%", { "a", "b", "c" } },
    { "a.b..c", ".", { "a", "b", "", "c" } },
    { "a.b..c.", ".", { "a", "b", "", "c", "" } },
  }
  for feed in M.list_iter(feeds) do
    local str, del, expected = unpack(feed)
    local splits = M.split(str, del)
    assert(M.iter_equals(splits, expected), string.format("%s del=del", str, del))
  end
end

local function test_8()
  local source = function(stop)
    local count = 0
    return function()
      count = count + 1
      if count > stop then return end
      return count, count
    end
  end

  local it = M.map(function(a, b)
    return a + b
  end, source(5))

  assert(M.iter_equals(it, { 2, 4, 6, 8, 10 }))
end

test_0()
test_1()
test_2()
test_3()
test_5()
test_6()
test_7()

test_8()
