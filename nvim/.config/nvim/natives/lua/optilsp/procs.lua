local M = {}

local augroups = require("infra.augroups")
local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("optilsp.procs", "debug")
local prefer = require("infra.prefer")

local beckon_select = require("beckon.select")

local lsp = vim.lsp

local aug = augroups.Augroup("monitor-lsp-proc")

---NB: clients could be killed anywhere, then clientid becomes invalid
---@type {[integer]: integer} @{clientid: timestamp}
local detached_since = {}

function M.init()
  M.init = nil

  aug:repeats("LspAttach", {
    ---@param args {buf: integer, data: {client_id: integer}}
    callback = function(args) detached_since[args.data.client_id] = nil end,
  })

  aug:repeats("LspDetach", {
    ---@param args {buf: integer, data: {client_id: integer}}
    callback = function(args)
      local client = assert(lsp.get_client_by_id(args.data.client_id))

      for bufnr in pairs(client.attached_buffers) do
        if bufnr ~= args.buf then return end
      end

      detached_since[client.id] = os.time()
    end,
  })
end

function M.all()
  for _, client in ipairs(lsp.get_clients()) do
    local bufs = table.concat(dictlib.keys(client.attached_buffers), ",")
    jelly.info("#%d %s root=%s bufs=%s", client.id, client.name, client.root_dir, bufs)
  end
end

function M.idles()
  for client_id, since in pairs(detached_since) do
    local client = lsp.get_client_by_id(client_id)
    if client == nil then goto continue end

    jelly.info("#%d %s since=%s root=%s", client.id, client.name, os.date("%H:%M:%S", since), client.root_dir)

    ::continue::
  end
end

---@param expire_time? integer @in seconds, nil=5min
function M.expires(expire_time)
  expire_time = expire_time or (60 * 5)

  local clients = {} ---@type vim.lsp.Client[]
  do
    local now = os.time()
    for client_id, since in pairs(detached_since) do
      if now - since < expire_time then goto continue end

      local client = lsp.get_client_by_id(client_id)
      if client == nil then goto continue end

      table.insert(clients, client)
      jelly.info("expiring client#%d %s root=%s", client.id, client.name, client.root_dir)

      ::continue::
    end
    if #clients == 0 then return end
  end

  for _, client in ipairs(clients) do
    detached_since[client.id] = nil
    --todo: since client.stop() is not done immediately, there could be race conditions
    client.stop(true)
  end
end

do
  ---@param client vim.lsp.Client
  ---@return string
  local function fmt(client) return string.format("#%d %s root=%s", client.id, client.name, client.root_dir) end

  function M.restart()
    beckon_select(lsp.get_clients(), { prompt = "restart", format_item = fmt }, function(client)
      if client == nil then return end

      local bufs = dictlib.keys(client.attached_buffers)

      ---start the client by re-triggering FileType event on each attached bufs formerly
      local function start()
        for _, bufnr in ipairs(bufs) do
          ---NB: prefer.bo(k,v) wont trigger FileType event
          ctx.buf(bufnr, function() ex("setlocal", "filetype=" .. prefer.bo(bufnr, "filetype")) end)
        end
      end

      ---schedule is necessary here
      ---@diagnostic disable-next-line: invisible
      table.insert(client._on_exit_cbs, vim.schedule_wrap(start))

      jelly.debug("stopping client#%d", client.id)
      client.stop(true)
    end)
  end
end

return M
