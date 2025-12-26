-- todo: put it in a standalone process?

local dictlib = require("infra.dictlib")
local its = require("infra.its")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

local facts = require("sh.facts")

---@alias Interpret fun(line: string): boolean,string[]

---@type {[string]: Interpret}
local interpreters = {}
do
  ---@type Interpret
  function interpreters.vimscript(line)
    local ok, result = pcall(ni.exec2, line, { output = true })
    if not ok then return false, { assert(result) } end

    local output = assert(result.output)
    return true, strlib.splits(output, "\n")
  end

  ---@type Interpret
  function interpreters.lua(line)
    if strlib.startswith(line, "=") then line = string.format("return vim.inspect(%s)", string.sub(line, 2)) end

    local chunk, load_err = loadstring(line)
    if not chunk then return false, { assert(load_err) } end

    local ok, result = pcall(chunk)
    if not ok then return false, { assert(result) } end

    local output = vim.inspect(result)
    return true, strlib.splits(output, "\n")
  end

  function interpreters.sh(line)
    --meant to be sh/dash instead of bash, zsh
    local _ = line
    error("not implemented")
  end
end

local triage
do
  local ex ---@type {[string]: true}
  do
    local excludes = its({ "print" }):toset()
    ex = its(io.lines(facts.excmd_fpath)) --
      :filter(function(cmd) return not excludes[cmd] end)
      :toset()
  end

  --usercmds
  --todo: case-insensitive: Man
  --todo: overwrites ex: Cp -> cp
  local ucmd = its(dictlib.iter_keys(ni.get_commands({ builtin = false }))) --
    :toset()

  local sh = its({ "realpath" }):toset()

  ---@param line string
  ---@return Interpret?
  function triage(line)
    do
      local char0 = string.sub(line, 1, 1)
      if char0 == ":" then return interpreters.vimscript end
      if char0 == "=" then return interpreters.lua end
    end

    do
      local cmd = strlib.iter_splits(line, " ")()
      if ex[cmd] then return interpreters.vimscript end
      if ucmd[cmd] then return interpreters.vimscript end
      if sh[cmd] then return interpreters.sh end
    end

    return interpreters.lua
  end
end

---@return thread
return function()
  return coroutine.create(function()
    while true do
      local line = coroutine.yield()
      assert(line ~= nil and line ~= "")
      local interpret = triage(line)
      if interpret ~= nil then
        local ok, results = interpret(line)
        coroutine.yield(ok, results)
      else
        coroutine.yield(false, { "no available interpreter" })
      end
    end
  end)
end
