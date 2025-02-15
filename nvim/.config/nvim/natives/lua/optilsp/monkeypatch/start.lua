local its = require("infra.its")

---@param client vim.lsp.Client
---@param config vim.lsp.ClientConfig
---@return boolean
local function is_reusable(client, config)
  if client.name ~= config.name then return false end

  ---NB: root_dir=nil indicates single file mode

  if config.root_dir == nil then
    return client.root_dir == nil
  else
    if client.root_dir == nil then return false end
    if client.root_dir == config.root_dir then return true end
    return its(client.workspace_folders):project("name"):contains(config.root_dir)
  end
end

---@param config vim.lsp.ClientConfig
---@param opts vim.lsp.start.Opts
---@return any
return function(config, opts)
  local origins = require("optilsp.monkeypatch").origins
  opts.reuse_client = is_reusable
  return origins.start(config, opts)
end
