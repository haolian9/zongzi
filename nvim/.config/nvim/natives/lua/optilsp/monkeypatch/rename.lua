local protocol = require("vim.lsp.protocol")
local lsputil = require("vim.lsp.util")

local its = require("infra.its")
local jelly = require("infra.jellyfish")("optilsp.rename", "debug")
local logging = require("infra.logging")
local ni = require("infra.ni")

local puff = require("puff")

local log = logging.newlogger("optilsp.rename", "info")
local Methods = protocol.Methods

---@param bufnr integer
---@param range {start: {character:integer, line:integer}, ['end']: {character:integer, line:integer}}
---@param offset_encoding string
---@return string
local function get_text_at_range(bufnr, range, offset_encoding)
  local start_lnum = range.start.line
  local start_col = lsputil._get_line_byte_from_position(bufnr, range.start, offset_encoding)
  local stop_lnum = range["end"].line
  local stop_col = lsputil._get_line_byte_from_position(bufnr, range["end"], offset_encoding)
  return ni.buf_get_text(bufnr, start_lnum, start_col, stop_lnum, stop_col, {})[1]
end

---@class optilsp.rename.Context
---@field client any
---@field bufnr integer
---@field winid integer
---@field cword string
---@field new_name? string
---@field advised_name? string

---@param ctx optilsp.rename.Context
local function rename(ctx)
  local params = lsputil.make_position_params(ctx.winid, ctx.client.offset_encoding)
  params.newName = assert(ctx.new_name)
  local handler = ctx.client.handlers[Methods.textDocument_rename] or vim.lsp.handlers[Methods.textDocument_rename]
  ctx.client.request(Methods.textDocument_rename, params, function(...) handler(...) end, ctx.bufnr)
end

---@param ctx optilsp.rename.Context
local function direct_routine(ctx)
  puff.input({ icon = "🔄", prompt = "rename", default = ctx.advised_name or ctx.cword }, function(new_name)
    if new_name == nil or new_name == "" then return end
    ctx.new_name = new_name
    rename(ctx)
  end)
end

---@param ctx optilsp.rename.Context
local function preapre_routine(ctx)
  local params = lsputil.make_position_params(ctx.winid, ctx.client.offset_encoding)
  ctx.client.request(Methods.textDocument_prepareRename, params, function(err, result)
    if err then return jelly.warn("Error on prepareRename: " .. (err.message or "")) end
    if result == nil then return jelly.warn("Nothing to rename") end
    log.debug("prepare result: %s", result)

    local advised_name
    -- result: Range | { range: Range, placeholder: string }
    if result.placeholder then
      advised_name = result.placeholder
    elseif result.start then
      advised_name = get_text_at_range(ctx.bufnr, result, ctx.client.offset_encoding)
    elseif result.range then
      advised_name = get_text_at_range(ctx.bufnr, result.range, ctx.client.offset_encoding)
    end
    ctx.advised_name = advised_name

    direct_routine(ctx)
  end, ctx.bufnr)
end

--- @class vim.lsp.buf.rename.Opts
--- @field filter? fun(client: vim.lsp.Client): boolean?
--- @field name? string

--- Renames all references to the symbol under the cursor.
---
---@param new_name string|nil If not provided, the user will be prompted for a new name using |vim.ui.input()|.
---@param opts? vim.lsp.buf.rename.Opts Additional options:
return function(new_name, opts)
  opts = opts or {}

  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local client
  do
    local clients = its(vim.lsp.get_clients({ bufnr = bufnr, method = Methods.textDocument_rename, name = opts.name })) --
      :filter(opts.filter)
      :tolist()
    if #clients == 0 then vim.info("no available langserver") end
    if #clients > 1 then return jelly.warn("too many langservers") end
    client = clients[1]
  end

  ---@type optilsp.rename.Context
  local ctx = { client = client, winid = winid, bufnr = bufnr, new_name = new_name, cword = vim.fn.expand("<cword>") }

  if new_name then return rename(ctx) end

  if client.supports_method(Methods.textDocument_prepareRename) then
    preapre_routine(ctx)
  else
    direct_routine(ctx)
  end
end
