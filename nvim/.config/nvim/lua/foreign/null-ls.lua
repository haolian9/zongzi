local M = {}

local nuls = require("null-ls")
local builtins = nuls.builtins

function M.setup()
  nuls.setup({
    sources = {
      builtins.diagnostics.mypy,
      -- builtins.diagnostics.pylint,
      builtins.diagnostics.flake8.with({
        -- stylua: ignore
        args = {
          "--format", "default",
          "--stdin-display-name", "$FILENAME",
          "--ignore=E121,E123,E126,E226,E24,E704,E501,E203,W503,E722",
          "-",
        },
      }),
      builtins.diagnostics.shellcheck,
    },
  })
  nuls.register({
    -- require("xnuls.comp-zig-fn"),
    require("xnuls.comp-lua-objects"),
    require("xnuls.comp-lua-locals-require"),
    --require("xnuls.lint-zig-check"),
    -- require("xnuls.lint-nim-check"),
  })
end

return M
