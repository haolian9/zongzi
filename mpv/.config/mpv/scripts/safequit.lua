--purpose
--* to quit playlist intentionally

local rhs
do
  local count = 0

  local function quitable()
    if mp.get_property_number("playlist-count") <= 1 then return true end

    count = count + 1
    return count > 1
  end

  function rhs()
    if not quitable() then return mp.osd_message("press again to quit") end
    mp.command("quit")
  end
end

mp.add_forced_key_binding("q", rhs)
mp.add_forced_key_binding("enter", rhs)
mp.add_forced_key_binding("kp_enter", rhs)
mp.add_forced_key_binding("mbtn_right_dbl", rhs)

