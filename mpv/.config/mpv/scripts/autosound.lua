--purpose
--* auto sound/mute when enter/exit fullscreen mode
--* only works when fullscreen and mute=yes

local observer
do
  local muted_on_full

  ---@param fullscreen boolean
  function observer(_, fullscreen)
    if fullscreen then
      muted_on_full = mp.get_property_bool("mute")
      if muted_on_full then mp.set_property_bool("mute", false) end
    else
      if muted_on_full then mp.set_property_bool("mute", true) end
    end
  end
end

mp.observe_property("fullscreen", "bool", observer)
