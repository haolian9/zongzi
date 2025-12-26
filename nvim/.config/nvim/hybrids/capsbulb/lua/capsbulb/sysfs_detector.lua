local M = {}

local fs = require("infra.fs")
local strlib = require("infra.strlib")

local get_brightness_file
do
  local brit_file

  local function is_kb_dev(path)
    local file = io.open(fs.joinpath(path, "device", "name"), "r")
    if file == nil then return false end
    local name = file:read("*a")
    file:close()
    return strlib.contains(string.lower(name), "keyboard")
  end

  function get_brightness_file()
    if brit_file ~= nil then return brit_file end

    local paths = vim.fn.globpath("/sys/class/leds", "input*::capslock", true, true)

    local kbcaps_path
    for _, path in ipairs(paths) do
      if is_kb_dev(path) then
        kbcaps_path = path
        break
      end
    end
    assert(kbcaps_path, "no keyboard capslock led detected")

    local brightness_path = fs.joinpath(kbcaps_path, "brightness")
    brit_file = assert(io.open(brightness_path, "r"))

    --concern: dont let the fp leak

    return brit_file
  end
end

---@return boolean
function M.is_capslock_on()
  local file = get_brightness_file()
  file:seek("set", 0)
  return file:read("*a") == "1\n"
end

return M
