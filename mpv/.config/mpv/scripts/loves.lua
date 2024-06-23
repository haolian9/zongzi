--purpose
--* /oasis/sync/censored -> /oasis/sync/censored-loves
--* /oasis/sync/nomosaic -> /oasis/sync/nomosaic-loves

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
    ---@param fpath string @absolute
    ---@return string?
    local function resolve_love_dir(fpath)
      if startswith(fpath, "/oasis/sync/censored") then
        return "/oasis/sync/censored-loves"
      elseif startswith(fpath, "/oasis/sync/nomosaic") then
        return "/oasis/sync/nomosaic-loves"
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
      local dir = assert(resolve_love_dir(fpath), "no love here")

      local name = string.match(fpath, "/[^/]+$")
      local dest = dir .. name
      assert(file_exists(fpath), "src missing")
      assert(not file_exists(dest), "dest exists")

      os.rename(fpath, dest)
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
