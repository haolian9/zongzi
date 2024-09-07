local M = {}

local cthulhu = require("cthulhu")
local augroups = require("infra.augroups")
local iuv = require("infra.iuv")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

local facts = {
  expire = 5, --seconds
  interval = 1000 * 1, --milliseconds
}

local timer = iuv.new_timer() ---@type uv_timer_t
local aug = nil ---@type infra.Augroup?

function M.activate()
  if aug then return end

  local last_cmd = 0
  aug = augroups.Augroup("msgcleaner://")
  aug:repeats("CmdlineLeave", { callback = function() last_cmd = os.time() end })

  local last_clean = 0

  local function clean()
    if strlib.startswith(ni.get_mode().mode, "c") then return end
    local last_msg = cthulhu.nvim.last_msg_time()

    local last_activity = math.max(last_msg, last_cmd)
    if last_activity <= last_clean then return end

    local now = os.time()
    if now - last_activity < facts.expire then return end

    last_clean = last_activity
    ni.echo({ { "" } }, false, { verbose = false })
  end

  timer:stop()
  timer:start(facts.interval, facts.interval, vim.schedule_wrap(clean))
end

function M.deactivate()
  if aug == nil then return end

  timer:stop()
  aug:unlink()
  aug = nil
end

return M
