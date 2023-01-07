local modeline = require("windmill.modeline")

local function test()
  local feed = {
    ["// %s"] = "//", -- zig
    ["# %s"] = "#", -- python
    ["//%s"] = "//", -- rust
    ["#%s"] = "#", -- sh
    ["/* %s */"] = "/*",
    ["/*%s*/"] = "/*", -- c
    ["--%s"] = "--", -- lua
    [""] = nil,
    [" "] = nil,
    [" %s"] = nil,
  }

  for pattern, expected in pairs(feed) do
    assert(modeline.inlinecmd_prefix(pattern) == expected)
  end
end

test()
