local itertools = require("infra.itertools")
local M = require("infra.listlib")

local function test_3() --
  local list = { 1, 2, 3, 4 }

  do
    local slice = M.slice(list, 0, 1)
    assert(itertools.equals(slice, { 1 }))
  end

  do
    local slice = M.slice(list, 2, 4)
    assert(itertools.equals(slice, { 3, 4 }))
  end

  do
    local slice = M.slice(list, 2, 6)
    assert(itertools.equals(slice, { 3, 4 }))
  end
end

test_3()
