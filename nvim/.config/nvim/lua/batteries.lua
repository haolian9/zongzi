local M = {}

local profiles = require("profiles")

---@class batteries.PluginRtps
---@field pre string
---@field post string?
---@field plugin string?
---
---@class batteries.Facts
---@field plugin_rtps table<'pre'|'post'|'plugin', batteries.PluginRtps>
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
  local dict
  do
    local path = string.format("%s/%s", vim.fn.stdpath("data"), "batteries.json")
    --intended to not use coreutils.cat here for less require in bootstrap phase
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    --@type batteries.Facts
    dict = vim.json.decode(data)
  end
  dict.native_rtps = vim.split(native_rtps, ",", { plain = true })
  do
    local root = vim.fn.stdpath("config")
    local function path(subdir) return root .. "/" .. subdir end
    local function rtp(subdir) return { pre = path(subdir) } end
    --stylua: ignore start
    dict.plugin_rtps.cthulhu  = rtp("cthulhu")
    dict.plugin_rtps.natives  = rtp("natives")
    dict.plugin_rtps.wiki     = rtp("hybrids/wiki")
    dict.plugin_rtps.guwen    = rtp("hybrids/guwen")
    dict.plugin_rtps.cricket  = rtp("hybrids/cricket")
    dict.plugin_rtps.sh       = rtp("hybrids/sh")
    dict.plugin_rtps.beckon   = rtp("hybrids/beckon")
    dict.plugin_rtps.capsbulb = rtp("hybrids/capsbulb")
  end
  do
    local root = vim.env.VIMRUNTIME .. "/plugin"
    local function path(file) return root .. "/" .. file end
    dict.builtin_plugins = {
      path("man.lua"),
      -- "editorconfig.lua", "nvim.lua", "shada.vim"
    }
  end
  return dict
end)(vim.go.rtp)

--order matters
---@type table<string, string[]>[]
local profile_plugins = {
  { "base", { "natives", "beckon", "sh" } },
  { "halhacks", { "cthulhu" } },
  { "joy", { "wiki", "guwen", "cricket", "capsbulb" } },
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

--todo: honor after/plugin
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

function M.aslist()
  local result = {}
  for plugin in pairs(facts.plugin_rtps) do
    if M.has(plugin) then table.insert(result, plugin) end
  end

  return result
end

return M
