--- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/

local M = {}

local jelly = require("infra.jellyfish")("optilsp.handlers")
local fn = require("infra.fn")
local logging = require("infra.logging")

local api = vim.api
local lsputil = vim.lsp.util
local orig_gd = vim.lsp.handlers["textDocument/definition"]
local log = logging.newlogger("optilsp.handlers", logging.INFO)

do
  ---@class optilsp.Definition
  local Definition = {
    -- variant 1: lua-langserver
    originSelectionRange = { ["end"] = { character = 1, line = 10 }, start = { character = 0, line = 10 } },
    targetRange = { ["end"] = { character = 16, line = 8 }, start = { character = 15, line = 8 } },
    targetSelectionRange = { ["end"] = { character = 16, line = 8 }, start = { character = 15, line = 8 } },
    targetUri = "file:///home/haoliang/scratch/hello.lua",
    -- variant 2: zls, clangd
    range = { ["end"] = { character = 15, line = 549 }, start = { character = 11, line = 549 } },
    uri = "file:///usr/include/stdio.h",
  }

  local keyfns = (function()
    ---@param defn optilsp.Definition
    local function sumneko_lua(defn)
      return string.format("%s:%s", defn.targetUri, defn.targetRange.start.line)
    end
    ---@param defn optilsp.Definition
    local function general(defn)
      return string.format("%s:%s", defn.uri, defn.range.start.line)
    end
    return {
      sumneko_lua = sumneko_lua,
      zls = general,
      pyright = general,
      clangd = general,
      gopls = general,
      rust_analyzer = sumneko_lua,
      phpactor = general,
    }
  end)()

  -- factory of goto definition handler
  ---@param split_cmd ?string @vs, sp
  local function gd_factory(split_cmd)
    ---@param result optilsp.Definition[]
    local handler = function(_, result, ctx)
      -- stolen from $VIMRUNTIME/lua/vim/lsp/handlers.lua :: location_handler

      log.debug("gd result: %s", result)
      if result == nil or vim.tbl_isempty(result) then return jelly.info("No location found") end

      if split_cmd then api.nvim_command(split_cmd) end

      -- result is a Definition rather than a Definition[]
      if result[1] == nil then return orig_gd(_, result, ctx, { reuse_win = false }) end

      -- distinct item based on file & start line
      local distinct = {}
      do
        assert(result[1] ~= nil, "the result of definition locations is not a list")

        local keyfn
        do
          local client_name = vim.lsp.get_client_by_id(ctx.client_id).name
          keyfn = keyfns[client_name]
          if keyfn == nil then error(string.format("unsupported langserver (%s) response for gd: '%s'", client_name, vim.inspect(result))) end
        end

        local grouped = {}
        for _, ent in ipairs(result) do
          local key = keyfn(ent)
          if grouped[key] == nil then grouped[key] = ent end
        end

        for _, ent in pairs(grouped) do
          table.insert(distinct, ent)
        end
      end

      orig_gd(_, distinct, ctx, { reuse_win = false })
    end

    local function request()
      local params = vim.lsp.util.make_position_params()
      vim.lsp.buf_request(0, "textDocument/definition", params, handler)
    end

    return request
  end

  M.rhs_gd = gd_factory(nil)
  M.rhs_gd_vs = gd_factory("vsplit")
  M.rhs_gd_sp = gd_factory("split")
end

-- see neovim/runtime/lua/vim/lsp/handlers.lua
do
  local spliters = (function()
    local function is_mark(line)
      local prefix = string.sub(line, 1, 3)
      if prefix == "---" then return true end
      if prefix == "```" then return true end
      return false
    end

    local function sumneko_lua(str)
      if str == "" then return function() end end

      local source = fn.split_iter(str, "\n")
      local blank_count = 0

      return function()
        for line in source do
          if not is_mark(line) then
            if line == "" then
              blank_count = blank_count + 1
              -- no 2+ blank lines
              if blank_count == 1 then return line end
            elseif vim.startswith(line, "@*param*") then
              -- lua-langserver specific
              blank_count = 1
              return line
            else
              blank_count = 0
              return line
            end
          end
        end
      end
    end

    local function general(str)
      if str == "" then return function() end end

      local source = fn.split_iter(str, "\n")
      local blank_count = 0

      return function()
        for line in source do
          if not is_mark(line) then
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
    end

    return {
      sumneko_lua = sumneko_lua,
      zls = general,
      pyright = general,
      clangd = general,
      gopls = general,
      rust_analyzer = general,
      phpactor = general,
    }
  end)()

  local function to_plains(opinionated_spliter, input, lines)
    lines = lines or {}
    if type(input) == "string" then
      fn.list_extend(lines, opinionated_spliter(input))
      return lines
    end

    assert(type(input) == "table", "Expected a table for Hover.contents")
    -- The kind can be either plaintext or markdown.
    if input.kind or input.language then
      -- Some servers send input.value as empty
      if input.value ~= nil then fn.list_extend(lines, opinionated_spliter(input.value)) end
    -- By deduction, this must be MarkedString[]
    else
      for _, marked in ipairs(input) do
        to_plains(marked, lines)
      end
    end
    return lines
  end

  function M.hover(_, result, ctx, config)
    config = config or {}
    config.focus_id = ctx.method

    log.debug("hover result: %s", result)
    if not (result and result.contents) then return jelly.info("No information available") end

    local spliter
    do
      local client_name = vim.lsp.get_client_by_id(ctx.client_id).name
      spliter = spliters[client_name]
      if spliter == nil then error(string.format("unsupported langserver (%s) response for hover: '%s'", client_name, vim.inspect(result))) end
    end

    local plains = to_plains(spliter, result.contents)
    if #plains == 0 then return jelly.info("No information available") end
    log.debug("hover plains: %s", plains)

    return lsputil.open_floating_preview(plains, nil, config)
  end
end

do
  ---@class optilsp.SignResult
  local Result = {
    -- variant 1: zls, lua-langserver
    activeParameter = 0,
    activeSignature = 0,
    signatures = {
      {
        activeParameter = 0,
        documentation = {
          kind = "markdown",
          value = 'Print to stderr, unbuffered, and silently returning on failure. Intended  \nfor use in "printf debugging." Use `std.log` functions for proper logging.',
        },
        label = "fn print(comptime fmt: []const u8, args: anytype) void",
        parameters = {
          { documentation = { kind = "markdown", value = "" }, label = "comptime fmt: []const u8" },
          { documentation = { kind = "markdown", value = "" }, label = "args: anytype" },
        },
      },
    },
  }

  ---@param result? optilsp.SignResult
  ---@return string[]|nil
  local function to_plains(result)
    if result == nil then return end
    if #result == 1 then return result end

    local set = {}
    for _, sign in ipairs(result.signatures or {}) do
      assert(sign.label ~= nil)
      set[sign.label] = true
    end

    return vim.tbl_keys(set)
  end

  function M.sign_help(_, result, ctx, config)
    config = config or {}
    config.focus_id = ctx.method

    log.debug("sign result: %s", result)
    local plains = to_plains(result)
    log.debug("sign plains: %s", plains)
    if plains == nil then return jelly.info("No information available") end

    return lsputil.open_floating_preview(plains, nil, config)
  end
end

return M
