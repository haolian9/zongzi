local M = {}

local bufpath = require("infra.bufpath")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("mill", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local engine = require("mill.engine")
local millets = require("mill.millets")

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

function M.run()
  local bufnr = ni.get_current_buf()

  local millet = millets.find(bufnr)
  jelly.debug("millet='%s'", millet)
  --to support: `source`, `source a.lua`, `source a.vim`
  if millet and strlib.startswith(millet, "source") then return engine.source(millet) end

  local fpath = bufpath.file(bufnr)
  if fpath == nil then return jelly.warn("not exists on disk") end

  if millet then -- try modeline first
    local cmd = millets.normalize(millet, fpath)
    assert(cmd[1] ~= "source")
    return engine.spawn(cmd)
  end

  do -- then ft
    local runner = filetype_runners[prefer.bo(bufnr, "filetype")]
    if runner ~= nil then
      local cmd = its(runner):chained({ fpath }):tolist()
      return engine.spawn(cmd)
    end
  end

  jelly.warn("no available runner")
end

return M
