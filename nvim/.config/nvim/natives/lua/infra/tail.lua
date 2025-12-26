-- design choices
-- * only buffer for each fpath
-- * only one window for each tab

local augroups = require("infra.augroups")
local bufrename = require("infra.bufrename")
local Ephemeral = require("infra.Ephemeral")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("infra.tail", "info")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

---@param fpath string @absolute path
---@param side infra.winsplit.Side
return function(fpath, side)
  if not fs.file_exists(fpath) then return jelly.warn("file not exists: %s", fpath) end

  local height, scrollback
  local host_winid = ni.get_current_win()
  do
    if side == "above" or side == "below" then
      height = math.floor(vim.fn.winheight(host_winid) / 2)
    else
      height = vim.fn.winheight(host_winid)
    end
    height = height - 1 --tabline
    height = height - 1 --statusline
    height = height - 1 --cmdline
    assert(height >= 2)
    scrollback = math.floor(height * 2)
  end

  local bufnr = Ephemeral()
  winsplit(side, bufnr)
  local winid = ni.get_current_win()

  local job

  local aug = augroups.BufAugroup(bufnr, "infra.tail", false)
  aug:once("TermOpen", { callback = function() prefer.bo(bufnr, "scrollback", scrollback) end })
  aug:once("BufWipeout", {
    callback = function()
      aug:unlink()
      vim.fn.jobstop(job)
    end,
  })

  do
    local cmd = { "tail", "-n", height, "-f", fpath }
    job = mi.become_term(cmd, { stdin = "null" })
    wincursor.follow(winid, "bol")
  end

  bufrename(bufnr, string.format("tail://%s", fpath))
end
