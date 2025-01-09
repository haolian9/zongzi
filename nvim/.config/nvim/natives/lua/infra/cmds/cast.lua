--design choices/limits/features
--* there will be only one positional argument
--* the flag pattern: '--{flag-flag}='
--* no abbrev for flags
--* no repeating flags
--* no `---`, use `-- -` instead
--
--todo: expand expr: %:p:h, @a
--todo: honor the flag.required constraint
--todo: complete no duplicate items for arg
--todo: path complete
--todo: generate completefn for {flag,arg}.type={true,boolean}

local ArgComp = require("infra.cmds.ArgComp")
local itertools = require("infra.itertools")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("imfra.cmds.cast", "debug")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

---@param spell infra.cmds.Spell
local function resolve_nargs(spell)
  if next(spell.flags) == nil then
    if spell.arg == nil then return 0 end
    if spell.arg.required then return 1 end
    return "?"
  end
  for _, d in pairs(spell.flags) do
    if d.required then return "+" end
  end
  if spell.arg and spell.arg.required then return "+" end
  return "*"
end

---@param spell infra.cmds.Spell
---@return boolean
local function resolve_range(spell) return spell.attrs.range == true end

local compose_complete
do
  ---@param line string
  local function collect_seen_flags(line)
    local iter = strlib.iter_splits(line, " ")
    local seen = {}
    for chunk in iter do
      if chunk == "--" then break end
      if strlib.startswith(chunk, "--") then
        --flag matching
        local eql_at = strlib.find(chunk, "=")
        if eql_at == nil then eql_at = -1 end
        local flag = string.sub(chunk, 3, eql_at - 1)
        seen[flag] = true
      end
    end

    return seen
  end

  ---@param spell infra.cmds.Spell
  ---@param prompt string
  ---@param line string
  local function resolve_unseen_flags(spell, prompt, line)
    local seen = collect_seen_flags(string.sub(line, 1, -(#prompt + 1)))
    local unseen = {}
    for flag, _ in pairs(spell.flags) do
      if not seen[flag] then table.insert(unseen, flag) end
    end
    return unseen
  end

  ---@return string[]|nil
  local function try_flags(spell, prompt, line, cursor)
    if next(spell.flags) == nil then return end

    --shold startswith -
    if not strlib.startswith(prompt, "-") then return end
    --no flags completion after ` -- `
    if strlib.contains(string.sub(line, 1, cursor + 1), " -- ") then return end

    -- -|, --{flag}|
    if prompt == "-" or prompt == "--" or not strlib.contains(prompt, "=") then
      local flags = resolve_unseen_flags(spell, prompt, line)
      if #flags == 0 then return end
      local comp = ArgComp.constant(function()
        return its(flags):map(function(f) return string.format("--%s", f) end):tolist()
      end)
      return comp(prompt)
    end

    do -- --{flag}=|, --{flag}=xx|
      --flag matching
      local eql_at = assert(strlib.find(prompt, "="))
      local flag = string.sub(prompt, 3, eql_at - 1)
      local decl = spell.flags[flag]
      if decl == nil then return {} end
      local comp = decl.complete
      if comp == nil then return {} end
      --if strlib.endswith(prompt, "=") then return comp("", line, cursor) end
      return comp(prompt, line, cursor)
    end
  end

  ---@param prompt string
  ---@return string[]
  local function try_arg(spell, prompt, line, cursor)
    if spell.arg.complete == nil then return {} end
    return spell.arg.complete(prompt, line, cursor)
  end

  ---@param spell infra.cmds.Spell
  ---@return infra.cmds.CompFn?
  function compose_complete(spell)
    if next(spell.flags) == nil then
      if spell.arg == nil then return end
      if spell.arg.complete == nil then return end
      return spell.arg.complete
    end

    assert(spell.arg)
    return function(prompt, line, cursor) return try_flags(spell, prompt, line, cursor) or try_arg(spell, prompt, line, cursor) or {} end
  end
end

local compose_action
do
  ---@param vtype infra.cmds.SpellVtype
  ---@param raw string
  ---@return any
  local function normalize_value(vtype, raw)
    if vtype == "string" then return raw end
    if vtype == "boolean" then
      if raw == "true" or raw == true then return true end
      if raw == "false" or raw == false then return false end
      return jelly.fatal("ValueError", "vtype=%s, raw=%s", vtype, raw)
    end
    if vtype == "true" then
      if raw == "true" or raw == true then return true end
      return jelly.fatal("ValueError", "vtype=%s, raw=%s", vtype, raw)
    end
    if vtype == "number" then
      local num = tonumber(raw)
      if num == nil then return jelly.fatal("ValueError", "vtype=%s, raw=%s", vtype, raw) end
      return num
    end
    if vtype == "string[]" then
      if raw == "" then return {} end
      return strlib.splits(raw, ",")
    end
    if vtype == "number[]" then
      if raw == "" then return {} end
      return its(strlib.iter_splits(raw, ",")):map(tonumber):tolist()
    end
    error("unexpected vtype: " .. vtype)
  end

  ---@param default infra.cmds.SpellDefault
  local function evaluate_default(default)
    if type(default) == "function" then return default() end
    return default
  end

  ---@alias infra.cmds.ParsedArgs {[string]: any}

  ---@param spell infra.cmds.Spell
  ---@param args string[]
  ---@return infra.cmds.ParsedArgs
  local function parse_args(spell, args)
    local parsed = {}

    do
      local iter = itertools.iter(args)
      local arg_chunks = {}
      -- --verbose, --verbose=true, --porcelain=v1
      for chunk in iter do
        ---nargs>1; {'--', '---'}
        if chunk == "--" then break end
        ---nargs=1; '-- ---'
        if strlib.startswith(chunk, "-- ") then break end

        if strlib.startswith(chunk, "--") then
          --flag matching
          local eql_at = strlib.find(chunk, "=")
          if eql_at ~= nil then
            local flag = string.sub(chunk, 3, eql_at - 1)
            local decl = spell.flags[flag]
            if decl then
              local val = string.sub(chunk, eql_at + 1)
              parsed[flag] = normalize_value(decl.type, val)
            else
              jelly.warn("unknown flag %s", flag)
            end
          else
            local flag = string.sub(chunk, 3)
            if spell.flags[flag] then
              parsed[flag] = true
            else
              jelly.warn("unknown flag %s", flag)
            end
          end
        else
          table.insert(arg_chunks, chunk)
        end
      end
      listlib.extend(arg_chunks, iter)
      --todo: honor arg.type
      if spell.arg and #arg_chunks > 0 then parsed[spell.arg.name] = itertools.join(arg_chunks, " ") end
    end

    do -- fill defaults
      for flag, decl in pairs(spell.flags) do
        local need_fill_flag = parsed[flag] == nil and decl.default ~= nil
        if need_fill_flag then parsed[flag] = evaluate_default(decl.default) end
      end
      local need_fill_arg = spell.arg and parsed[spell.arg.name] == nil and spell.arg.default ~= nil
      if need_fill_arg then parsed[spell.arg.name] = evaluate_default(spell.arg.default) end
    end

    --todo: honor the required constraint

    return parsed
  end

  ---@param spell infra.cmds.Spell
  function compose_action(spell)
    ---@param ctx infra.cmds.Args
    return function(ctx) spell.action(parse_args(spell, ctx.fargs), ctx) end
  end
end

---@param spell infra.cmds.Spell
return function(spell)
  ni.create_user_command(spell.name, compose_action(spell), {
    nargs = resolve_nargs(spell),
    range = resolve_range(spell),
    complete = compose_complete(spell),
  })
end
