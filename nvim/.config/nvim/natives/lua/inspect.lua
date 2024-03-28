local api = vim.api

local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local listlib = require("infra.listlib")
local rifts = require("infra.rifts")

return function(...)
  -- let inspect crash first
  local text = {}
  for arg in listlib.iter({ ... }) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    table.insert(text, vim.inspect(arg, { newline = "\n", indent = "  " }))
  end

  local bufnr = Ephemeral({ namepat = "inspect://{bufnr}", handyclose = true })

  rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.7, height = 0.9 })
  --intended to have no auto-close on winleave

  do
    local start = 0
    local iter = fn.iter_chained(fn.map(function(el) return fn.split_iter(el, "\n", nil, false) end, text))
    for lines in fn.batch(iter, 30) do
      api.nvim_buf_set_lines(bufnr, start, start + #lines, false, lines)
      start = start + #lines
    end
  end
end
