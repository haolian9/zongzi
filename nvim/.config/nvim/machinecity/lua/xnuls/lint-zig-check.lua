local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local DIAGNOSTICS = methods.internal.DIAGNOSTICS

-- todo: figure out how null-ls's architecture
return h.make_builtin({
  name = "zig-check",
  method = DIAGNOSTICS,
  filetypes = { "zig" },
  generator_opts = {
    command = "zig",
    args = function(params)
      local _ = params
      return { "ast-check", "--color", "off" }
    end,
    to_stdin = true,
    format = "line",
    check_exit_code = function(code)
      return code == 0
    end,
    from_stderr = true,
    on_output = h.diagnostics.from_pattern([[([^:]+):(%d+):(%d+): (%a+): (.*)]], { "filename", "row", "col", "severity", "message" }, {
      severities = {
        error = h.diagnostics.severities["error"],
      },
    }),
  },
  factory = h.generator_factory,
})
