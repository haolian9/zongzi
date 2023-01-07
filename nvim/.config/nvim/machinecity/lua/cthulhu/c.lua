local ffi = require("ffi")
local jelly = require("infra.jellyfish")("cthulhu", vim.log.levels.INFO)

ffi.cdef([[
  int cthulhu_notify(const char *summary, const char *body, const char *icon, unsigned int urgency, int timeout);
  void cthulhu_md5hex(const char *str, char *digest[32]);
  int cthulhu_rime_ascii_mode();
]])

local libs = setmetatable({}, {
  __index = (function()
    local root = string.format("%s/%s", vim.fn.stdpath("config"), "cthulhu")

    local function resolve_path(name)
      if name ~= "cthulhu" then name = "cthulhu-" .. name end
      return string.format("%s/%s/lib%s.so", root, "zig-out/lib", name)
    end

    return function(t, key)
      local path = resolve_path(key)
      local ok, lib = pcall(ffi.load, path, false)
      if not ok then
        jelly.err("failed to load %s from %s", key, path)
        error(lib)
      end

      t[key] = lib
      return lib
    end
  end)(),
})

return {
  notify = function(...)
    return libs.notify.cthulhu_notify(...)
  end,
  md5hex = function(...)
    return libs.md5.cthulhu_md5hex(...)
  end,
  rime_ascii_mode = function(...)
    return libs.rime.cthulhu_rime_ascii_mode(...)
  end,
}
