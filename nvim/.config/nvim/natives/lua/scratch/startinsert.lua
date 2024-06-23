---在切换到插入模式这块，nvim的api简直不可理喻: startinsert, feedkeys('i', 'nx')
---避免使用它

local feedkeys = require("infra.feedkeys")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("infra.startinsert")
local ni = require("infra.ni")

--:h mode()
local modes = {
  normal = itertools.toset({ "n", "no", "nov", "noV", "noCTRL-V", "CTRL-V", "niI", "niR", "niV", "nt", "ntT" }),
  visual = itertools.toset({ "v", "vs", "V", "Vs", "CTRL-V", "CTRL-Vs" }),
  select = itertools.toset({ "s", "S", "CTRL-S" }),
  insert = itertools.toset({ "i", "ic", "ix" }),
  replace = itertools.toset({ "R", "Rc", "Rx", "Rv", "Rvc", "Rvx" }),
  cmdline = itertools.toset({ "c", "cv" }),
  confirm = itertools.toset({ "r", "rm", "r?" }),
  shell = itertools.toset({ "!" }),
  term = itertools.toset({ "t" }),
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
    return modes.insert[ni.get_mode().mode] == true
  end)
  assert(done)
  assert(modes.insert[ni.get_mode().mode])
end

---@param how string @i, a, I, A
return function(how)
  if how == nil then how = "a" end

  local mode = ni.get_mode().mode
  jelly.debug("mode %s", mode)

  if modes.insert[mode] then return end
  if modes.term[mode] then return end

  if modes.normal[mode] then return wait_entered_insertmode(function() feedkeys(how, "n") end) end
  --todo: goto end of the visual region
  if modes.visual[mode] or modes.select[mode] then return wait_entered_insertmode(function() feedkeys("<esc>" .. how, "n") end) end

  if modes.replace[mode] then error("startinsert in replace mode?") end
  if modes.cmdline[mode] then error("startinsert in cmdline mode?") end
  if modes.confirm[mode] then error("startinsert in confirm mode?") end
  if modes.shell[mode] then error("startinsert in shell mode?") end

  error("unexpected mode: " .. mode)
end

