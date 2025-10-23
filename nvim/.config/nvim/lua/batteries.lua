local M = {}

local profiles = require("profiles")

---@class batteries.PluginRtps
---@field pre string
---@field post string?
---@field plugin string?
---
---@class batteries.Facts
---@field plugin_rtps table<string, batteries.PluginRtps>
---@field native_rtps string[]
---@field builtin_plugins string[]
local Facts = {}
---@class batteries.Facts.filesystem
---@field root string
---@field data string
---@field treesitter_libdir string
Facts.filesystem = {}

---@type batteries.Facts
local facts = (function(native_rtps)
  local base
  do
    local path = string.format("%s/%s", vim.fn.stdpath("data"), "batteries.json")
    --intended to not use coreutils.cat here for less require in bootstrap phase
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    base = vim.json.decode(data)
  end
  base.native_rtps = vim.split(native_rtps, ",", { plain = true })
  do
    local root = vim.fn.stdpath("config")
    local function path(sub) return root .. "/" .. sub end
    base.plugin_rtps.cthulhu = { pre = path("cthulhu") }
    base.plugin_rtps.natives = { pre = path("natives") }
    base.plugin_rtps.wiki = { pre = path("hybrids/wiki") }
    base.plugin_rtps.guwen = { pre = path("hybrids/guwen") }
    base.plugin_rtps.cricket = { pre = path("hybrids/cricket") }
    base.plugin_rtps.sh = { pre = path("hybrids/sh") }
    base.plugin_rtps.beckon = { pre = path("hybrids/beckon") }
    base.plugin_rtps.capsbulb = { pre = path("hybrids/capsbulb") }
  end
  do
    local root = vim.env.VIMRUNTIME .. "/plugin"
    local files = { "man.lua", "shada.vim" } -- "editorconfig.lua", "nvim.lua"
    base.builtin_plugins = {}
    for i, val in ipairs(files) do
      base.builtin_plugins[i] = root .. "/" .. val
    end
  end
  return base
end)(vim.go.rtp)

--order matters
local profile_plugins = {
  { "base", { "cthulhu", "natives", "beckon", "sh" } },
  { "joy", { "guwen", "cricket", "wiki", "capsbulb" } },
}

local function valid_native_rtp(rtp)
  ---according to nvim/runtime.c::runtimepath_default, &rtp
  ---* stdpath(config)            -> /home/haoliang/.config/nvim
  ---* stdpath(config_dirs)       -> /etc/xdg/nvim
  ---* stdpath(data)/site         -> /home/haoliang/.local/share/nvim/site
  ---* stdpath(data_dirs)/site    -> /usr/local/share/nvim/site, /usr/share/nvim/site
  ---* $VIMRUNTIME/site           -> /opt/nvim-hal/share/nvim/runtime
  ---* lib_dir                    -> /opt/nvim-hal/lib/nvim
  ---* stdpath(data_dirs)/after   -> /usr/share/nvim/site/after, /usr/local/share/nvim/site/after
  ---* stdpath(data)/after        -> /home/haoliang/.local/share/nvim/site/after
  ---* stdpath(config_dirs)/after -> /etc/xdg/nvim/after
  ---* stdpath(config)/after      -> /home/haoliang/.config/nvim/after

  -- no system-wide xdg config
  if vim.startswith(rtp, "/etc/xdg/nvim") then return false end
  -- no more vim packages
  if string.find(rtp, "/site", 1, true) then return false end
  -- no vimfiles/
  if string.find(rtp, "/vim/vimfiles", 1, true) then return false end
  return true
end

function M.install()
  local rtps = {}
  do
    local pre, post = {}, {}
    for _, defn in ipairs(profile_plugins) do
      local profile, plugins = unpack(defn)
      if profiles.has(profile) then
        for _, plugin in ipairs(plugins) do
          local rtp = facts.plugin_rtps[plugin]
          if rtp ~= nil then
            table.insert(pre, rtp.pre)
            table.insert(post, rtp.post)
          end
        end
      end
    end

    -- order:
    -- * stdpath('config')
    -- * batteries.plugins.pre
    -- * vim.default.{pre,after}
    -- * batteries.plugins.after
    local tip = vim.fn.stdpath("config")
    table.insert(rtps, tip)
    table.insert(rtps, facts.filesystem.treesitter_libdir)
    -- pre's
    for _, path in ipairs(pre) do
      table.insert(rtps, path)
    end
    for _, path in ipairs(facts.native_rtps) do
      if path ~= tip and valid_native_rtp(path) then table.insert(rtps, path) end
    end
    -- post's
    for _, path in ipairs(post) do
      table.insert(rtps, path)
    end
  end

  vim.go.rtp = table.concat(rtps, ",")
end

local function source_file(fpath)
  local ok, err = xpcall(vim.api.nvim_cmd, debug.traceback, { cmd = "source", args = { fpath } }, {})
  if not ok then error(string.format("failed to source file=%s error=%s", fpath, err)) end
end

-- todo: honor after/plugin
function M.load_rtp_plugins()
  for _, defn in ipairs(profile_plugins) do
    local profile, plugins = unpack(defn)
    if profiles.has(profile) then
      for _, plugin in ipairs(plugins) do
        local plugin_file = facts.plugin_rtps[plugin].plugin
        if plugin_file then source_file(plugin_file) end
      end
    end
  end

  for _, plugin_file in ipairs(facts.builtin_plugins) do
    source_file(plugin_file)
  end
end

function M.datadir(ent) return string.format("%s/%s", facts.filesystem.data, ent) end

---@param plugin string
---@return boolean
function M.has(plugin)
  local function found(profile, plugins)
    if not profiles.has(profile) then return false end
    for _, val in ipairs(plugins) do
      if val == plugin then return true end
    end
    return false
  end

  for _, defn in ipairs(profile_plugins) do
    if found(unpack(defn)) then return true end
  end

  return false
end

return M
