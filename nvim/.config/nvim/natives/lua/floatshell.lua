local augroups = require("infra.augroups")
local bufpath = require("infra.bufpath")
local bufrename = require("infra.bufrename")
local ex = require("infra.ex")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("floatshell")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local bufnr, winid

---@param cwd? string @nil=%:p:h
return function(cwd)
  cwd = cwd or bufpath.dir(ni.get_current_buf())
  if cwd == nil then return jelly.err("cant resolve cwd") end

  local need_init_buf = not (bufnr and ni.buf_is_valid(bufnr))
  local need_open_win = not (winid and ni.win_is_valid(winid))

  if need_init_buf then
    bufnr = ni.create_buf(false, true) --no ephemeral here
    handyclosekeys(bufnr)

    local aug = augroups.BufAugroup(bufnr, "floatshell", true)
    aug:once("TermClose", {
      nested = true,
      callback = function()
        --only closing window when the last command exits normally
        if vim.v.event.status == 1 then return end
        ni.win_close(0, false)
        ni.buf_delete(bufnr, { force = false })
      end,
    })
  end

  if need_open_win then
    --intended to have no auto-close on winleave
    winid = rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.8, height = 0.8 })
    prefer.wo(winid, "list", false)
  end

  if need_init_buf then --init term after all operations are done
    local jobid = mi.become_term(vim.env.SHELL or "/bin/sh", { cwd = cwd })
    bufrename(bufnr, string.format("term://%d", jobid))
  end

  ex("startinsert")
end
