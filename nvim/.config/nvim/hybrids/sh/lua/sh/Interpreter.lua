-- todo: put it in a standalone process?

local fn = require("infra.fn")
local strlib = require("infra.strlib")

local facts = require("sh.facts")

local api = vim.api

---@alias Interpret fun(line: string): boolean,string[]

---@type {[string]: Interpret}
local interpreters = {}
do
  ---@type Interpret
  function interpreters.vimscript(line)
    local ok, result = pcall(api.nvim_exec2, line, { output = true })
    if not ok then return false, { assert(result) } end

    local output = assert(result.output)
    return true, fn.split(output, "\n")
  end

  ---@type Interpret
  function interpreters.lua(line)
    if strlib.startswith(line, "=") then line = string.format("return vim.inspect(%s)", string.sub(line, 2)) end

    local chunk, load_err = loadstring(line)
    if not chunk then return false, { assert(load_err) } end

    local ok, result = pcall(chunk)
    if not ok then return false, { assert(result) } end

    local output = vim.inspect(result)
    return true, fn.split(output, "\n")
  end

  function interpreters.sh(line)
    --meant to be sh/dash instead of bash, zsh
    local _ = line
    error("not implemented")
  end
end

local triage
do
  local ex = fn.toset(io.lines(facts.excmd_fpath))
  for _, name in ipairs({ "print" }) do
    ex[name] = nil
  end

  local sh = fn.toset({ "realpath" })

  ---@param line string
  ---@return Interpret?
  function triage(line)
    do
      local char0 = string.sub(line, 1, 1)
      if char0 == ":" then return interpreters.vimscript end
      if char0 == "=" then return interpreters.lua end
    end

    do
      local cmd = fn.split_iter(line, " ")()
      if ex[cmd] then return interpreters.vimscript end
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
