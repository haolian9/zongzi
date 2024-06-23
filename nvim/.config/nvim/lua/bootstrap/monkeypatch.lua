-- do -- 跟 langser 的使用一比，4096? 这都不是事
--   local orig = vim.json.decode
--   local file = assert(io.open("/tmp/vimjsondecode.sizes", "a"))
--   function vim.json.decode(str, opts)
--     if #str > 4096 then error("json too large") end
--     return orig(str, opts)
--   end
-- end

do
  local orig = assert(vim.api.nvim_get_option_value)
  function vim.api.nvim_get_option_value(name, opts)
    -- > this will trigger |ftplugin| and all |FileType| autocommands for the corresponding filetype.
    -- personally, i will never use it.
    if opts.filetype ~= nil then error("no use of opts.filetype") end
    return orig(name, opts)
  end
end

vim.notify_once = function() error("no use of notify_once") end

vim.validate = function() return true end
