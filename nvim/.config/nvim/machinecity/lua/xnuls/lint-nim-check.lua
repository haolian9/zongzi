local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local DIAGNOSTICS = methods.internal.DIAGNOSTICS

return h.make_builtin({
  name = "nim-check",
  method = DIAGNOSTICS,
  filetypes = { "nim" },
  generator_opts = {
    command = "nim",
    args = function(params)
      return {
        "check",
        "--verbosity:0",
        "--colors:off",
        "--threads:on",
        "--listFullPaths",
        "$FILENAME",
      }
    end,
    to_temp_file = true,
    from_stderr = true,
    format = "raw",
    -- FIXME
    on_output = h.diagnostics.from_errorformat(
      table.concat({
        "%f(%l, %c) %trror: %m",
        "%f(%l, %c) %tarning: %m",
        "%A%f(%l, %c) Hint: %m",
        "%I%f(%l, %c) %m",
        "%-IHint: %m",
        "%-ICC: %m",
      }, ","),
      "nim-check"
    ),
  },
  factory = h.generator_factory,
})
