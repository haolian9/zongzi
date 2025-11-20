local rhs
do
  ---@param a string
  ---@param b string
  ---@return boolean
  local function startswith(a, b) return string.sub(a, 1, #b) == b end

  local function resolve_current_fpath()
    local fpath = assert(mp.get_property("path"))

    if startswith(fpath, "/") then return fpath end

    local cwd = assert(mp.get_property("working-directory"))
    if startswith(fpath, "./") then fpath = string.sub(fpath, 3) end
    fpath = string.format("%s/%s", cwd, fpath)

    return fpath
  end

  local love
  do
    local routes = {
      ["/oasis/sync/"] = "/oasis/sync/loves",
      ["/oasis/smaug/"] = "/oasis/sync/loves",
      ["/av/"] = "/av/sync/loves",
      ["/mnt/a4wd1/"] = "/mnt/a4wd1/av/loves",
      ["/mnt/u4wd1/"] = "/mnt/u4wd1/av/loves",
      ["/mnt/d1wd1/"] = "/mnt/d1wd1/av/loves",
      ["/mnt/m1wd1/"] = "/mnt/m1wd1/av/loves",
    }

    ---@param fpath string @absolute
    ---@return string?
    local function resolve_love_dir(fpath)
      for prefix, dest in pairs(routes) do
        if startswith(fpath, prefix) then return dest end
      end
    end

    local function file_exists(fpath)
      local file = io.open(fpath, "r")
      if file == nil then return false end
      file:close()
      return true
    end

    ---@param fpath string @absolute path
    function love(fpath)
      assert(file_exists(fpath), "src missing")

      local dest
      do
        local dir = assert(resolve_love_dir(fpath), "no love here")
        local name = string.match(fpath, "/[^/]+$")
        dest = dir .. name

        if fpath == dest then return end
        assert(not file_exists(dest), "dest exists")
      end

      os.rename(fpath, dest)
      os.execute(string.format("notify-send 'mpv-loves' '%s\n%s'", fpath, dest))
    end
  end

  function rhs()
    local fpath = resolve_current_fpath()

    if assert(mp.get_property_number("playlist-count")) == 1 then
      love(fpath)
      mp.command("quit")
    else
      mp.commandv("playlist-remove", "current")
      love(fpath)
    end
  end
end

mp.add_forced_key_binding("c", rhs)
mp.add_forced_key_binding("wheel_left", rhs)
