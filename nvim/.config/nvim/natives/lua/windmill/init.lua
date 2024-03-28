local M = {}

local bufpath = require("infra.bufpath")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("windmill")
local prefer = require("infra.prefer")

local engine = require("windmill.engine")
local find_modeline = require("windmill.find_modeline")

local api = vim.api

local filetype_runners = {
  python = { "python" },
  zig = { "zig", "run" },
  sh = { "sh" },
  bash = { "bash" },
  lua = { "luajit" },
  c = { "ccrun" },
  go = { "go", "run" },
  nim = { "nim", "compile", "--hints:off", "--run" },
  php = { "php" },
}

function M.ftrun()
  local bufnr = api.nvim_get_current_buf()
  local fpath = bufpath.file(bufnr)
  if fpath == nil then return jelly.info("no file associated to buf#d", bufnr) end

  -- try modeline first
  do
    local cmd = find_modeline(bufnr, fpath)
    if cmd ~= nil then return engine.run(cmd) end
  end

  -- then ft
  do
    local runner = filetype_runners[prefer.bo(bufnr, "filetype")]
    if runner ~= nil then
      local cmd = fn.tolist(fn.chained(runner, { fpath }))
      return engine.run(cmd)
    end
  end

  jelly.info("no runner available for this buf#%d", bufnr)
end

M.run = engine.run

return M
