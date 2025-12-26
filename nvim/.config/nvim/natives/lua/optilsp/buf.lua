local M = {}

local lspro = require("vim.lsp.protocol")
local lsputil = require("vim.lsp.util")

local dictlib = require("infra.dictlib")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("optilsp", "info")
local listlib = require("infra.listlib")
local logging = require("infra.logging")
local mi = require("infra.mi")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

local open_floatwin = require("optilsp.open_floatwin")
local puff = require("puff")

local log = logging.newlogger("optilsp", "info")
local lsp = vim.lsp

local HOVER = lspro.Methods.textDocument_hover
local SIGNATURE = lspro.Methods.textDocument_signatureHelp
local RENAME = lspro.Methods.textDocument_rename
local PREPARE_RENAME = lspro.Methods.textDocument_prepareRename

---@param bufnr integer
---@param method string
---@return vim.lsp.Client?
local function get_responsible_client(bufnr, method)
  local clients = lsp.get_clients({ bufnr = bufnr, method = method })
  if #clients == 0 then return jelly.info("no available langserver for %s", method) end
  local client = clients[1]
  if #clients > 1 then jelly.info("dispatch %s to langserver #id %s", method, client.id, client.name) end
  return client
end

local LastWin
do
  ---@class optilsp.buf.LastWin
  ---@field opid string
  ---@field winid integer
  local impl = {}
  impl.__index = impl

  ---@param winid integer
  ---@param bufnr integer
  ---@param position lsp.TextDocumentPositionParams
  ---@return string
  function impl.generate_opid(winid, bufnr, position)
    local ctick = ni.buf_get_changedtick(bufnr)
    local parts = { winid, position.position.line, position.position.character, bufnr, ctick }
    return table.concat(parts, ":")
  end

  ---@param opid string
  ---@return boolean
  function impl:is_reusable(opid)
    if self.opid == nil or self.winid == nil then return false end
    if opid ~= self.opid then return false end
    if not ni.win_is_valid(self.winid) then return false end
    if mi.win_is_landed(self.winid) then return false end
    return true
  end

  function impl:remember(opid, winid)
    self.opid = opid
    self.winid = winid
  end

  function LastWin() return setmetatable({}, impl) end
end

do
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
    local handler = ctx.client.handlers[RENAME] or vim.lsp.handlers[RENAME]
    ctx.client:request(RENAME, params, function(...) handler(...) end, ctx.bufnr)
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
    ctx.client.request(PREPARE_RENAME, params, function(err, result)
      if err then return jelly.warn("error on prepareRename: " .. (err.message or "")) end
      if result == nil then return jelly.warn("nothing to rename") end
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

  ---customize:
  ---* only one langser to do the job
  ---* puff.input
  ---
  ---@param new_name? string
  ---@param opts? vim.lsp.buf.rename.Opts
  function M.rename(new_name, opts)
    opts = opts or {}

    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)
    local client = get_responsible_client(bufnr, RENAME)
    if client == nil then return end

    ---@type optilsp.rename.Context
    local ctx = { client = client, winid = winid, bufnr = bufnr, new_name = new_name, cword = vim.fn.expand("<cword>") }

    if new_name then return rename(ctx) end

    if client:supports_method(PREPARE_RENAME, bufnr) then
      preapre_routine(ctx)
    else
      direct_routine(ctx)
    end
  end
end

do
  ---@param lines string[]|fun():string?
  ---@return string[]
  local function trim_inline_ln(lines)
    return its(lines) --
      :map(function(el)
        if not strlib.contains(el, "\n") then return el end
        local result = el
        result = string.gsub(result, "\n +", " ")
        result = string.gsub(result, "\n", "")
        return result
      end)
      :tolist()
  end

  ---@param result? optilsp.SignResult
  ---@return string[]|nil
  local function to_plains(result)
    if result == nil then return end
    if #result == 1 then return trim_inline_ln(result) end

    local set = {}
    for _, sign in ipairs(result.signatures or {}) do
      ---@diagnostic disable: undefined-field
      assert(sign.label ~= nil)
      set[sign.label] = true
    end

    return trim_inline_ln(dictlib.iter_keys(set))
  end

  local lastwin = LastWin()

  local function on_response(result, _, opts)
    opts.close_events = { "InsertLeave" }

    log.debug("result: %s", result)
    local plains = to_plains(result)
    log.debug("plains: %s", plains)
    if plains == nil then return jelly.info("no information available") end

    return open_floatwin(plains, nil, opts)
  end

  function M.show_signature(opts)
    opts = opts or {}

    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    local client = get_responsible_client(bufnr, SIGNATURE)
    if client == nil then return end

    local params = lsputil.make_position_params(winid, client.offset_encoding)
    local opid = lastwin.generate_opid(winid, bufnr, params)
    if lastwin:is_reusable(opid) then return ni.set_current_win(lastwin.winid) end

    client:request(SIGNATURE, params, function(err, result, ctx)
      if err ~= nil then return jelly.err("err on signature_help: %s", err) end
      local _, hover_winid = on_response(result, ctx, opts)
      lastwin:remember(opid, hover_winid)
    end, bufnr)
  end
end

do
  ---@type {[string]: fun(str: string): fun(): string?}
  local Spliter = {}
  do
    local function is_not_mark(line)
      local prefix = string.sub(line, 1, 3)
      if prefix == "---" then return false end
      if prefix == "```" then return false end
      return true
    end

    local function strip_uri(line) --
      return string.gsub(line, [[%(http(s?)://[^)]+%)]], "")
    end

    function Spliter.luals(str)
      if str == "" then
        return function() end
      end

      local splits = strlib.splits(str, "\n")
      --last line is just uri
      if strlib.startswith(splits[#splits], "[View documents]") then splits[#splits] = nil end
      --remove head/tail blank lines
      for _ = 1, math.floor(#splits / 2) do
        if splits[1] == "" then table.remove(splits, 1) end
        if splits[#splits] == "" then splits[#splits] = nil end
      end

      local source = its(splits) --
        :filter(is_not_mark)
        :map(strip_uri)

      local blank_count = 0

      return function()
        for line in source do
          if line == "" then
            blank_count = blank_count + 1
            if blank_count > 1 then
            --continue
            else -- no 2+ blank lines
              return line
            end
          elseif strlib.startswith(line, "@*param*") then
            blank_count = 1
            return line
          elseif strlib.startswith(line, "@*return*") then
            blank_count = 1
            return line
          else
            blank_count = 0
            return line
          end
        end
      end
    end

    local function general(str)
      if str == "" then
        return function() end
      end

      local source = its(strlib.iter_splits(str, "\n"))
      source:filter(is_not_mark)

      local blank_count = 0

      return function()
        for line in source do
          if line == "" then
            blank_count = blank_count + 1
            -- no 2+ blank lines
            if blank_count == 1 then return line end
          else
            blank_count = 0
            return line
          end
        end
      end
    end

    Spliter.zls = general
    Spliter.pyright = general
    Spliter.ty = general
    Spliter.clangd = general
    Spliter.gopls = general
    Spliter.phpactor = general
    Spliter.cmakels = general
  end

  ---@param spliter fun(line: string): fun(): string?
  ---@param input string|string[]|{kind: string, language: string, value: string}
  ---@param lines? string[]
  ---@return string[]
  local function to_plains(spliter, input, lines)
    lines = lines or {}
    if type(input) == "string" then
      listlib.extend(lines, spliter(input))
      return lines
    end

    assert(type(input) == "table", "Expected a table for Hover.contents")
    -- The kind can be either plaintext or markdown.
    if input.kind or input.language then
      -- Some servers send input.value as empty
      if input.value ~= nil then listlib.extend(lines, spliter(input.value)) end
    -- By deduction, this must be MarkedString[]
    else
      for _, marked in ipairs(input) do
        to_plains(spliter, marked, lines)
      end
    end
    return lines
  end

  local lastwin = LastWin()

  local function on_response(result, ctx, opts)
    log.debug("hover result: %s", result)
    if not (result and result.contents) then return jelly.info("No information available") end

    local spliter
    do
      local client_name = lsp.get_client_by_id(ctx.client_id).name
      spliter = Spliter[client_name]
      if spliter == nil then error(string.format("unsupported langserver %s", client_name)) end
    end

    local plains = to_plains(spliter, result.contents)
    if #plains == 0 then return jelly.info("No information available") end
    log.debug("hover plains: %s", plains)

    return open_floatwin(plains, nil, opts)
  end

  function M.hover(opts)
    opts = opts or {}

    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    local client = get_responsible_client(bufnr, HOVER)
    if client == nil then return end

    local params = lsputil.make_position_params(winid, client.offset_encoding)
    local opid = lastwin.generate_opid(winid, bufnr, params)
    if lastwin:is_reusable(opid) then return ni.set_current_win(lastwin.winid) end

    client:request(HOVER, params, function(err, result, ctx)
      if err ~= nil then return jelly.err("err on hover: %s", err) end
      local _, hover_winid = on_response(result, ctx, opts)
      lastwin:remember(opid, hover_winid)
    end, bufnr)
  end
end

return M
