---partialy stolen from https://zenn.dev/anyakichi/articles/a3aab8d80994d1
---see src/addonloader/luaaddonstate.cpp, /usr/include/Fcitx5

---notes on the fn param of fcitx.watchEvent
---* the fn must be global
---* if the fn returns true, event.filterAndAccept() will be called, and this <esc> will be discarded

---@type fcitx
local fcitx = require("fcitx")

local last_file = nil

---@param sym number
---@param state number
---@param is_release boolean
function NVIM_AFFINITY_HANDLE(sym, state, is_release)
  do -- so the pressed key is <esc> and the IM is rime
    local is_escape = (sym == 65307 and state == 0) or (sym == 91 and state == 4)
    if not (is_escape and not is_release) then return end
    if fcitx.currentInputMethod() ~= "rime" then return end
  end

  ---reap the zombie produced by io.popen
  ---
  ---this process is supposed to be finished at the time user presses <esc> again
  ---so we are safe to reap/kill it now
  if last_file ~= nil then
    last_file:close()
    last_file = nil
  end

  ---lua addon will block the fcitx5 process including the dbus of rime,
  ---thus we should use either `--timeout=0` or `--expect-reply=no` here.
  ---see also: busctl introspect --user org.fcitx.Fcitx5 /rime
  -- os.execute([[busctl call --user --expect-reply=no org.fcitx.Fcitx5 /rime org.fcitx.Fcitx.Rime1 SetAsciiMode b 1]])

  ---os.execute invokes a shell which is slightly heavier than io.popen
  ---yet io.popen will produce zombie processes!
  -- os.execute("rimeascii &")
  last_file = io.popen("rimeascii")
end

fcitx.watchEvent(fcitx.EventType.KeyEvent, "NVIM_AFFINITY_HANDLE")
