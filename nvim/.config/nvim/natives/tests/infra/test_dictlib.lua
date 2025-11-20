local dictlib = require("infra.dictlib")

local function test_1()
  local function counts(dict)
    local count = 0
    for _ in pairs(dict) do
      count = count + 1
    end
    return count
  end

  local seen = {}
  local dict = { a = 1, b = 2, c = 3, [1] = "a", [0] = true }
  for k, v in dictlib.items(dict) do
    assert(seen[k] == nil)
    assert(v == dict[k])
    seen[k] = true
  end

  assert(counts(dict) == counts(seen))
end

test_1()
