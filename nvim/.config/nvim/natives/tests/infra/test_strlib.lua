local itertools = require("infra.itertools")
local M = require("infra.strlib")

local function test_0()
  do
    local found_at = M.rfind("/a/b/c", "/")
    assert(found_at == #"/a/b/")
  end
  do
    local found_at = M.rfind("/a/b//c", "/")
    assert(found_at == #"/a/b//")
  end
  do
    local found_at = M.rfind("/a/b//c", "/b")
    assert(found_at == #"/a/")
  end
end

local function test_1()
  do
    local stripped = M.lstrip(" // a/b/c", "/ ")
    assert(stripped == "a/b/c", stripped)
  end
  do
    local stripped = M.rstrip("/a/b/c// /", "/ ")
    assert(stripped == "/a/b/c", stripped)
  end
  do
    local stripped = M.strip([[' /a/b/c// /']], "'/ ")
    assert(stripped == "a/b/c", stripped)
  end

  do
    local stripped = M.rstrip("///", "/")
    assert(stripped == "", stripped)
  end
  do
    local stripped = M.lstrip("////", "/")
    assert(stripped == "", stripped)
  end
  do
    local stripped = M.strip("////", "/")
    assert(stripped == "", stripped)
  end
end

local function test_2()
  do
    local stripped = M.lstrip("////a", "/")
    assert(stripped == "a", stripped)
  end
  do
    local stripped = M.rstrip("a///", "/")
    assert(stripped == "a", stripped)
  end
  do
    local stripped = M.strip("//a//", "/")
    assert(stripped == "a", stripped)
  end
  do
    local stripped = M.strip(" \ta\t\t ", " \t")
    assert(stripped == "a", stripped)
  end
end

local function test_3()
  do
    assert(M.startswith("abc", "a"))
    assert(not M.startswith("abc", "b"))
    assert(M.startswith("a", "a"))
    assert(not M.startswith("", "a"))
    assert(M.startswith("", ""))
  end

  do
    assert(M.endswith("abc", "c"))
    assert(not M.endswith("abc", "b"))
    assert(M.endswith("a", "a"))
    assert(not M.endswith("", "a"))
    assert(M.endswith("", ""))
  end
end

local function test_4()
  local feeds = {
    { "a:b:c:d", 0, { "a:b:c:d" } },
    { "a:b:c:d", 1, { "a", "b:c:d" } },
    { "a:b:c:d", 2, { "a", "b", "c:d" } },
    { "a:b:c:d", 3, { "a", "b", "c", "d" } },
    { "a:b:c:d", 4, { "a", "b", "c", "d" } },
  }

  for feed in itertools.iter(feeds) do
    local str, maxsplit, expected = unpack(feed)
    local splits = M.splits(str, ":", maxsplit)
    assert(itertools.equals(splits, expected), string.format("%s maxsplit=%d", str, maxsplit))
  end
end

local function test_5()
  local feeds = {
    { "a:b:c:d", 0, { "a:b:c:d" } },
    { "a:b:c:d", 1, { "a:", "b:c:d" } },
    { "a:b:c:d", 2, { "a:", "b:", "c:d" } },
    { "a:b:c:d", 3, { "a:", "b:", "c:", "d" } },
    { "a:b:c:d", 4, { "a:", "b:", "c:", "d" } },
  }

  for feed in itertools.iter(feeds) do
    local str, maxsplit, expected = unpack(feed)
    local splits = M.splits(str, ":", maxsplit, true)
    assert(itertools.equals(splits, expected))
  end
end

local function test_6()
  local feeds = {
    { "a.b.c", ".", { "a", "b", "c" } },
    { "a%b%c", "%", { "a", "b", "c" } },
    { "a.b..c", ".", { "a", "b", "", "c" } },
    { "a.b..c.", ".", { "a", "b", "", "c", "" } },
  }
  for feed in itertools.iter(feeds) do
    local str, del, expected = unpack(feed)
    local splits = M.splits(str, del)
    assert(itertools.equals(splits, expected), string.format("%s del=del", str, del))
  end
end

local function test_9()
  local iter = M.iter_splits("abc\ndef", "\n", nil, true)
  do
    local chunk = iter()
    assert(chunk == "abc\n", chunk)
  end
  do
    local chunk = iter()
    assert(chunk == "def", chunk)
  end
  do
    local chunk = iter()
    assert(chunk == nil, chunk)
  end
end

local function test_10()
  local iter = M.iter_splits("infra.fn", ".")
  do
    local chunk = iter()
    assert(chunk == "infra", chunk)
  end
  do
    local chunk = iter()
    assert(chunk == "fn", chunk)
  end
  do
    local chunk = iter()
    assert(chunk == nil, chunk)
  end
end

local function test_11()
  do
    local iter = M.iter_splits("", ".")
    assert(iter() == "")
    assert(iter() == nil)
  end
  do
    local iter = M.iter_splits("infra", ".")
    assert(iter() == "infra")
    assert(iter() == nil)
  end
end

local function test_12()
  do
    local iter = M.iter_splits("a\nb\n", "\n", nil, true)
    assert(iter() == "a\n")
    assert(iter() == "b\n")
    assert(iter() == "")
    assert(iter() == nil)
  end
end

local function test_13()
  assert(M.slice("abcdefhijklmnop", 0, 3) == "abc")
  assert(M.slice("abcdefhijklmnop", 1, 3) == "bc")
  assert(M.slice("abcdefhijklmnop", 2, 3) == "c")
  assert(M.slice("abcdefhijklmnop", 3, 3) == "")

  assert(M.slice("abcdefhijklmnop", 3) == "abc")
  assert(M.slice("abcdefhijklmnop", 0) == "")
  assert(M.slice("abcdefhijklmnop", 1) == "a")
  assert(M.slice("abcdefhijklmnop", 2) == "ab")
end

test_0()
test_1()
test_2()
test_3()
test_4()
test_5()
test_6()
test_9()
test_10()
test_11()
test_12()
test_13()
