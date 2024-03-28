local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("optilsp.handlers")
local listlib = require("infra.listlib")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local open_floatwin = require("optilsp.open_floatwin")

local lsp = vim.lsp
local log = logging.newlogger("optilsp.handlers.hover", logging.INFO)

local function is_mark(line)
  local prefix = string.sub(line, 1, 3)
  if prefix == "---" then return true end
  if prefix == "```" then return true end
  return false
end

local function luals(str)
  if str == "" then return function() end end

  local source
  source = fn.split_iter(str, "\n")
  source = fn.filter(function(line) return not is_mark(line) end, source)

  local blank_count = 0

  return function()
    for line in source do
      if line == "" then
        blank_count = blank_count + 1
        -- no 2+ blank lines
        if blank_count == 1 then return line end
      elseif strlib.startswith(line, "@*param*") then
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

local function general(str)
  if str == "" then return function() end end

  local source
  source = fn.split_iter(str, "\n")
  source = fn.filter(function(line) return not is_mark(line) end, source)

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

local spliters = {
  luals = luals,
  zls = general,
  pyright = general,
  clangd = general,
  gopls = general,
  phpactor = general,
}

---@param spliter fun(line: string): string[]
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

return function(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method

  log.debug("hover result: %s", result)
  if not (result and result.contents) then return jelly.info("No information available") end

  local spliter
  do
    local client_name = lsp.get_client_by_id(ctx.client_id).name
    spliter = spliters[client_name]
    if spliter == nil then error(string.format("unsupported langserver %s", client_name)) end
  end

  local plains = to_plains(spliter, result.contents)
  if #plains == 0 then return jelly.info("No information available") end
  log.debug("hover plains: %s", plains)

  return open_floatwin(plains, nil, config)
end
