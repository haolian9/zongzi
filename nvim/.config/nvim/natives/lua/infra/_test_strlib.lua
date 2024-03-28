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

test_0()
test_1()
test_2()
test_3()
