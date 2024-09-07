local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("optilsp.handlers")
local listlib = require("infra.listlib")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local open_floatwin = require("optilsp.monkeypatch.open_floatwin")

local log = logging.newlogger("optilsp.hover", "info")
local lsp = vim.lsp

---@type {[string]: fun(str: string): fun(): string?}
local Spliter = {}
do
  local function is_mark(line)
    local prefix = string.sub(line, 1, 3)
    if prefix == "---" then return true end
    if prefix == "```" then return true end
    return false
  end

  function Spliter.luals(str)
    if str == "" then return function() end end

    local source
    source = strlib.iter_splits(str, "\n")
    source = itertools.filter(source, function(line) return not is_mark(line) end)

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
    if str == "" then return function() end end

    local source
    source = strlib.iter_splits(str, "\n")
    source = itertools.filter(source, function(line) return not is_mark(line) end)

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

return function(_, result, ctx, opts)
  opts = opts or {}
  opts.focus_id = ctx.method

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
