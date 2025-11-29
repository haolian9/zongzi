--purpose
--* trash the playing file
--* respect the mount point

local rhs
do
  ---@param a string
  ---@param b string
  ---@return boolean
  local function startswith(a, b) return string.sub(a, 1, #b) == b end

  local function resolve_fpath()
    local fpath = assert(mp.get_property("path"))

    if startswith(fpath, "/") then return fpath end

    local cwd = assert(mp.get_property("working-directory"))
    if startswith(fpath, "./") then fpath = string.sub(fpath, 3) end
    fpath = string.format("%s/%s", cwd, fpath)

    return fpath
  end

  local trash
  do
    ---@param fpath string @absolute
    ---@return string
    local function resolve_trash_dir(fpath)
      local file, err = io.popen("stat -c %m " .. fpath)
      if file == nil then error(err) end

      local mount = file:read("*a")
      file:close()

      mount = string.sub(mount, 1, #mount - 1) -- \n

      return string.format("%s/umbra-trash", mount)
    end

    local function file_exists(fpath)
      local file = io.open(fpath, "r")
      if file == nil then return false end
      file:close()
      return true
    end

    ---@param fpath string @absolute path
    function trash(fpath)
      assert(file_exists(fpath), "src missing")

      local dest
      do
        local dir = resolve_trash_dir(fpath)
        local name = string.match(fpath, "/[^/]+$")
        dest = dir .. name
        if fpath == dest then return end
        assert(not file_exists(dest), "dest exists")
      end

      os.rename(fpath, dest)
    end
  end

  function rhs()
    local fpath = resolve_fpath()

    if assert(mp.get_property_number("playlist-count")) == 1 then
      trash(fpath)
      mp.command("quit")
    else
      mp.commandv("playlist-remove", "current")
      trash(fpath)
    end
  end
end

mp.add_forced_key_binding("d", rhs)
mp.add_forced_key_binding("wheel_right", rhs)
