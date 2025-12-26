---design choices
---* no use of client.commands
---* each buffer should only have one lsp client attached

local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("optilsp.cmds", "debug")
local ni = require("infra.ni")

local puff = require("puff")
local lsp = vim.lsp

---@type {[string]: {[string]: fun(client: vim.lsp.Client, bufnr: integer)}} @{langser-name: {cmd-name: fun}}
local langser_cmds = {}
do
  --luals:
  --caps: { "lua.removeSpace", "lua.solve", "lua.jsonToLua", "lua.setConfig", "lua.getConfig", "lua.autoRequire" }
  langser_cmds.luals = {
    ---@param client vim.lsp.Client
    ---@param bufnr integer
    remove_space = function(client, bufnr)
      client.request("workspace/executeCommand", {
        command = "lua.removeSpace",
        arguments = { { uri = vim.uri_from_bufnr(bufnr) } },
      }, nil, bufnr)
    end,
  }

  --clangd
  --caps: { "clangd.applyFix", "clangd.applyTweak" }

  --gopls
  --doc: https://go.googlesource.com/tools/+/refs/heads/master/gopls/doc/commands.md
  --caps: { "gopls.add_dependency", "gopls.add_import", "gopls.apply_fix", "gopls.check_upgrades", "gopls.edit_go_directive",
  -- "gopls.fetch_vulncheck_result", "gopls.gc_details", "gopls.generate", "gopls.go_get_package", "gopls.list_imports",
  -- "gopls.list_known_packages", "gopls.mem_stats", "gopls.regenerate_cgo", "gopls.remove_dependency",
  -- "gopls.reset_go_mod_diagnostics", "gopls.run_go_work_command", "gopls.run_govulncheck", "gopls.run_tests",
  -- "gopls.start_debugging", "gopls.start_profile", "gopls.stop_profile", "gopls.test", "gopls.tidy", "gopls.toggle_gc_details",
  -- "gopls.update_go_sum", "gopls.upgrade_dependency", "gopls.vendor", "gopls.workspace_stats" }
end

return function()
  local bufnr = ni.get_current_buf()

  local client
  do
    local clients = lsp.get_active_clients({ bufnr = bufnr })
    assert(#clients == 1, "not supposed to have multiple clients attached")
    client = clients[1]
  end

  local cmds = langser_cmds[client.name]
  if not (cmds and next(cmds)) then return jelly.info("no lsp cmds available from %s", client.name) end

  puff.select(dictlib.keys(cmds), { prompt = "lsp cmds" }, function(name)
    if name == nil then return end
    assert(cmds[name])(client, bufnr)
  end)
end
