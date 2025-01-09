local LRU = require("infra.LRU")

local function test_0()
  local lru = LRU(2)
  lru[1] = 1
  lru[2] = 2
  lru[3] = 3

  assert(lru[1] == nil)
  assert(lru[2] == 2)
  assert(lru[3] == 3)
end

local function test_1()
  local lru = LRU(2)
  lru[1] = 1
  lru[2] = 2
  local _ = lru[1]

  lru[3] = 3

  assert(lru[1] == 1)
  assert(lru[2] == nil)
  assert(lru[3] == 3)
end

local function test_2()
  local lru = LRU(2)
  lru[1] = 1
  lru[2] = 2

  print(vim.inspect(getmetatable(lru)))

  local count = 0
  for _, _ in pairs(lru) do
    count = count + 1
  end
  assert(count == 2)
end

test_0()
test_1()
test_2()
