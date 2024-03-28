-- do -- 跟 langser 的使用一比，4096? 这都不是事
--   local orig = vim.json.decode
--   local file = assert(io.open("/tmp/vimjsondecode.sizes", "a"))
--   function vim.json.decode(str, opts)
--     if #str > 4096 then error("json too large") end
--     return orig(str, opts)
--   end
-- end

do
  local orig = vim.api.nvim_get_option_value
  function vim.api.nvim_get_option_value(name, opts)
    -- > this will trigger |ftplugin| and all |FileType| autocommands for the corresponding filetype.
    -- personally, i will never use it.
    if opts.filetype ~= nil then error("no use of opts.filetype") end
    return orig(name, opts)
  end
end

vim.notify_once = function() error("no use of notify_once") end

do
  local orig = _G.require

  local aliases = { ["infra.keymap.buffer"] = "bufmap", ["infra.keymap.global"] = "m" }

  local function resolve_as(name)
    local alias = aliases[name]
    if alias ~= nil then return alias end
    if string.find(name, ".", 1, true) then return end
    return name
  end

  ---@param name string
  ---@return any
  function _G.require(name)
    local mod = orig(name)
    local as = resolve_as(name)
    if as == nil then return mod end
    if _G[as] ~= nil then return mod end
    _G[as] = mod
    return mod
  end
end
