-- partialy stolen from https://zenn.dev/anyakichi/articles/a3aab8d80994d1

local fcitx = require("fcitx")

fcitx.watchEvent(fcitx.EventType.KeyEvent, "handler")

-- have to be global!
function handler(sym, state, release)
  --- it seems `return false` mean `un-handled`

  local is_escape = (sym == 65307 and state == 0) or (sym == 91 and state == 4)
  if not (is_escape and not release) then return false end

  local curim = fcitx.currentInputMethod()
  if curim ~= "rime" then return false end

  -- lua script will block the whole fcitx process including the rime's dbus
  -- so we should use either `--timeout` or `--expect-reply` here.
  --
  -- see also: busctl introspect --user org.fcitx.Fcitx5 /rime
  --os.execute([[busctl call --user --expect-reply=no org.fcitx.Fcitx5 /rime org.fcitx.Fcitx.Rime1 SetAsciiMode b 1]])
  os.execute([[rimeascii &]])

  return false
end
