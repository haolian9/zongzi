---在切换到插入模式这块，nvim的api简直不可理喻: startinsert, feedkeys('i', 'nx')
---避免使用它

local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("infra.startinsert")
local nvimkeys = require("infra.nvimkeys")

local api = vim.api

--:h mode()
local modes = {
  normal = fn.toset({ "n", "no", "nov", "noV", "noCTRL-V", "CTRL-V", "niI", "niR", "niV", "nt", "ntT" }),
  visual = fn.toset({ "v", "vs", "V", "Vs", "CTRL-V", "CTRL-Vs" }),
  select = fn.toset({ "s", "S", "CTRL-S" }),
  insert = fn.toset({ "i", "ic", "ix" }),
  replace = fn.toset({ "R", "Rc", "Rx", "Rv", "Rvc", "Rvx" }),
  cmdline = fn.toset({ "c", "cv" }),
  confirm = fn.toset({ "r", "rm", "r?" }),
  shell = fn.toset({ "!" }),
  term = fn.toset({ "t" }),
}

---@param proc fun()
local function wait_entered_insertmode(proc)
  --necessary as any way to entering insert mode delays
  local done = false
  vim.schedule(function()
    proc()
    done = true
  end)
  vim.wait(3000, function()
    if not done then return false end
    return modes.insert[api.nvim_get_mode().mode] == true
  end)
  assert(done)
  assert(modes.insert[api.nvim_get_mode().mode])
end

---@param how string @i, a, I, A
return function(how)
  if how == nil then how = "a" end

  local mode = api.nvim_get_mode().mode
  jelly.debug("mode %s", mode)

  if modes.insert[mode] then return end
  if modes.term[mode] then return end

  if modes.normal[mode] then return wait_entered_insertmode(function() api.nvim_feedkeys(how, "n", false) end) end
  --todo: goto end of the visual region
  if modes.visual[mode] or modes.select[mode] then return wait_entered_insertmode(function() api.nvim_feedkeys(nvimkeys("<esc>" .. how), "n", false) end) end

  if modes.replace[mode] then error("startinsert in replace mode?") end
  if modes.cmdline[mode] then error("startinsert in cmdline mode?") end
  if modes.confirm[mode] then error("startinsert in confirm mode?") end
  if modes.shell[mode] then error("startinsert in shell mode?") end

  error("unexpected mode: " .. mode)
end

