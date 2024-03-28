local M = require("optilsp.omnifunc.fuzzy")

local function test_1()
  local haystack = "stuff in plugin/ arent lua modules"
  do
    local needle = "siaarent"
    print(M.match_lower(haystack, needle))
  end
  do
    print(M.similar_lower(haystack, "sia"))
    print(M.similar_lower(haystack, "six"))
    print(M.similar_lower(haystack, "soxz"))
  end
end

test_1()
