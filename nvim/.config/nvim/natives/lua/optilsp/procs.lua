local M = {}

local augroups = require("infra.augroups")
local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("optilsp.procs", "debug")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

local beckon_select = require("beckon.select")

local lsp = vim.lsp

---@param bufnr integer
local function lsp_start(bufnr)
  ---NB: prefer.bo(k,v) wont trigger FileType event
  ---NB: re-calling bootstrap.langs.bufspecs.{lang}.lsp() should have no side effect
  ctx.buf(bufnr, function() ex("setlocal", "filetype=" .. prefer.bo(bufnr, "filetype")) end)
end

local aug = augroups.Augroup("optilsp://procs")

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
    --concern: since client.stop() is not done immediately, there could be race conditions
    client:stop(true)
  end
end

do
  ---@param client vim.lsp.Client
  ---@return string
  local function fmt(client) return string.format("#%d %s root=%s", client.id, client.name, client.root_dir) end

  function M.kill()
    beckon_select(lsp.get_clients(), { prompt = "lsp.kill", format_item = fmt }, function(client)
      if client == nil then return end
      client:stop()
    end)
  end

  function M.restart()
    beckon_select(lsp.get_clients(), { prompt = "lsp.restart", format_item = fmt }, function(client)
      if client == nil then return end

      local bufs = dictlib.keys(client.attached_buffers)

      ---start the client by re-triggering FileType event on each attached bufs formerly
      local function start()
        for _, bufnr in ipairs(bufs) do
          lsp_start(bufnr)
        end
      end

      ---schedule is necessary here
      ---@diagnostic disable-next-line: invisible
      table.insert(client._on_exit_cbs, vim.schedule_wrap(start))

      jelly.debug("stopping client#%d", client.id)
      client:stop(true)
    end)
  end
end

do
  local function resolve_bufname(bufnr)
    local name = ni.buf_get_name(bufnr)
    if name == "" then return "unnamed" end
    return fs.basename(name)
  end

  ---@return {[1]:vim.lsp.Client,[2]:integer}[] links (client,bufnr)[]
  local function enumerate_attach_links()
    local links = {}
    for _, client in pairs(lsp.get_clients()) do
      for bufnr in pairs(client.attached_buffers) do
        table.insert(links, { client, bufnr })
      end
    end
    return links
  end

  local function fmt(link)
    local client, bufnr = unpack(link)
    return string.format("%s - %s (%s:%s)", client.name, resolve_bufname(bufnr), client.id, bufnr)
  end

  function M.detach()
    local links = enumerate_attach_links()
    if #links == 0 then return jelly.info("no links found") end
    beckon_select(links, { prompt = "lsp.detach", format_item = fmt }, function(_, index)
      if index == nil then return end
      local client, bufnr = unpack(assert(links[index]))
      lsp.buf_detach_client(bufnr, client.id)
    end)
  end
end

return M
