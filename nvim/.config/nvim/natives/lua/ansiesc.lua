local buflines = require("infra.buflines")
local bufopen = require("infra.bufopen")
local Ephemeral = require("infra.Ephemeral")
local jelly = require("infra.jellyfish")("ansiesc", "debug")
local ni = require("infra.ni")

---@param name_or_nr string|integer @bufnr or file name
---@param open_mode infra.bufopen.Mode
return function(name_or_nr, open_mode)
  local function namefn(bufnr) return string.format("ansi://%s/%s", name_or_nr, bufnr) end
  local bufnr = Ephemeral({ namefn = namefn, modifiable = false })

  do --feed content to the terminal
    local tid = ni.open_term(bufnr, {})

    local lines
    if type(name_or_nr) == "number" then
      lines = buflines.iter(name_or_nr)
    else
      ---@cast name_or_nr string
      lines = io.lines(name_or_nr, "*l")
    end

    for line in lines do
      vim.fn.chansend(tid, line)
      vim.fn.chansend(tid, "\n")
    end

    vim.fn.chanclose(tid)
  end

  bufopen(open_mode, bufnr)
end

