local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local its = require("infra.its")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

return function(...)
  -- let inspect crash first
  local texts = {}
  for i = 1, select("#", ...) do
    local arg = select(i, ...)
    texts[i] = vim.inspect(arg, { newline = "\n", indent = "  " })
  end

  local bufnr = Ephemeral({ namepat = "inspect://{bufnr}", handyclose = true })

  rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.7, height = 0.9 })
  --intended to have no auto-close on winleave

  do
    local iter = its(texts) --
      :map(function(el) return strlib.iter_splits(el, "\n", nil, false) end)
      :flat()
      :batched(30)

    local start = 0
    for lines in iter do
      buflines.replaces(bufnr, start, start + #lines, lines)
      start = start + #lines
    end
  end
end
