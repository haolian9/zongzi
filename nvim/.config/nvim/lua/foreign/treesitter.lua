local M = {}

local ts_configs = require("nvim-treesitter.configs")
local fs = require("infra.fs")

function M.setup()
  local ts_data_dir = fs.joinpath(vim.fn.stdpath("data"), "treesitter")
  vim.opt.runtimepath:append(ts_data_dir)

  -- stylua: ignore
  local config = {
    parser_install_dir = ts_data_dir,
    ensure_installed = {
      -- tier 1
      "bash", "c", "python", "lua", "zig",
      -- tier 2
      "vim", "javascript",
      -- tier 3
      "rust", "cpp", "go", "fennel",
    },
    ignore_install = nil, -- List of parsers to ignore installing
    highlight = {
      enable = true,
      -- treesitter keep alerting on ft=help
      disable = {"help"},
      custom_captures = {
        ["docstring"] = "@comment",
      },
    },
    incremental_selection = { enable = false },
    indent = { enable = false },
  }

  config["playground"] = { enable = true }

  ts_configs.setup(config)
end

return M
