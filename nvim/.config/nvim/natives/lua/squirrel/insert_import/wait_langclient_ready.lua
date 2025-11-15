local augroups = require("infra.augroups")
local prefer = require("infra.prefer")

---@param bufnr integer @must be Ephemeral
---@param filetype string @must have langclient
return function(bufnr, filetype)
  ---assumption:
  ---* lua code is being executed in one thread in nvim, so sync is guaranteed by default
  ---* callbacks attached to an autocmd will be executed in order
  ---* no vim.schedule() will be used here

  local ready = false

  local aug = augroups.BufAugroup(bufnr, "wait_langclient_ready", true)
  aug:once("LspAttach", { callback = function() ready = true end })

  prefer.bo(bufnr, "filetype", filetype)

  vim.wait(1000, function() return ready end)
end
