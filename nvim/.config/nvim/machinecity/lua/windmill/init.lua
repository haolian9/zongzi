local M = {}

local api = vim.api
local engine = require("windmill.engine")
local modeline = require("windmill.modeline")
local jelly = require("infra.jellyfish")("windmill")
local fn = require("infra.fn")

local filetype_runners = {
  python = { "python" },
  zig = { "zig", "run" },
  sh = { "sh" },
  lua = { "luajit" },
  c = { "ccrun" },
  fennel = { "fennel" },
  go = { "go", "run" },
  nim = { "nim", "compile", "--hints:off", "--run" },
  rust = { "cargo", "run", "--quiet" },
  php = { "php" },
}

function M.autorun()
  local bufnr = api.nvim_get_current_buf()

  if not "practial" then
    if not engine.is_buf_changed(bufnr) then return jelly.info("no changes since last run") end
  end

  -- try modeline first
  do
    local cmd = modeline.runas(bufnr)
    if cmd ~= nil then return engine.run(cmd) end
  end

  -- todo: then ft
  do
    local runner = filetype_runners[api.nvim_buf_get_option(bufnr, "filetype")]
    if runner ~= nil then
      local fpath = vim.fn.expand("%:p")
      local cmd = fn.concrete(fn.chained(runner, { fpath }))
      return engine.run(cmd)
    end
  end

  jelly.info("no run cmd available for this buf#%d", bufnr)
end

M.run = engine.run

function M.preview_fennel()
  -- todo: use jobstart&on_stdout barely instead of termopen
  local bufnr = api.nvim_get_current_buf()
  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  if ft ~= "fennel" then return jelly.warn("only available for ft=fennel") end
  local fpath = api.nvim_buf_get_name(bufnr)
  if fpath == "" then return jelly.warn("not available for an unnamed buffer") end

  engine.run({ "fennel", "--compile", "--correlate", fpath })
end

return M
