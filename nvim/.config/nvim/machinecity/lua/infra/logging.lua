local coreutils = require("infra.coreutils")

local M = {}

---@class infra.logging.facts
local facts = {
  ---@type string
  root = nil,
  --{category: {path, file}}
  ---@type table<string, {path: string, file: file*?}>
  files = {},

  --{category: path}
  ---@type table<string, string>
  dirs = {},
}

do
  local user = coreutils.whoami()
  facts.root = string.format("/tmp/%s-nvim-logs", user)
  assert(coreutils.mkdir(facts.root))
end

M.DEBUG = vim.log.levels.DEBUG
M.INFO = vim.log.levels.INFO
M.WARN = vim.log.levels.WARN
M.ERROR = vim.log.levels.ERROR

---@param category string
---@param ensure_created ?boolean @default=true
---@return string,file*|nil
function M.newfile(category, ensure_created)
  if ensure_created == nil then ensure_created = true end

  if facts.files[category] == nil then facts.files[category] = {} end
  local ent = facts.files[category]

  if ent.path == nil then ent.path = string.format("%s/%s", facts.root, category) end
  if ensure_created then coreutils.touch(ent.path) end

  return ent.path, ent.file
end

---@param ensure_created ?boolean @default=true
---@return string
function M.newdir(category, ensure_created)
  if ensure_created == nil then ensure_created = true end

  local dir = facts.dirs[category]
  if dir ~= nil then return dir end

  dir = string.format("%s/%s", facts.root, category)
  if ensure_created then assert(coreutils.mkdir(dir)) end
  facts.dirs[category] = dir

  return dir
end

---@param file file*
local function BufferedWriter(file)
  ---@type string[]
  local stash = {}
  local count = 0

  local function flush()
    if count == 0 then return end
    local old_stash = stash
    stash = {}
    count = 0
    file:write(table.concat(old_stash, ""))
    file:flush()
  end

  local function throttled()
    if count > 4096 then return false end
    if #stash > 64 then return false end
    return true
  end

  ---@param str string
  local function write(str)
    table.insert(stash, str)
    count = count + #str
    if not throttled() then flush() end
  end

  return {
    write = write,
    flush = flush,
  }
end

M.newlogger = (function()
  local inteprete_msg

  do
    local inspect_opts = { newline = " ", indent = "" }

    inteprete_msg = function(format, ...)
      local args = {}
      for i = 1, select("#", ...) do
        local arg = select(i, ...)
        local t = type(arg)
        local repr = arg
        if not (t == "boolean" or t == "number" or t == "string") then
          --
          repr = vim.inspect(arg, inspect_opts)
        end
        table.insert(args, repr)
      end

      if #args ~= 0 then return string.format(format, unpack(args)) end

      assert(format ~= nil, "missing format")
      if string.find(format, "%%s") == nil then return format end
      error("unmatched args for format")
    end
  end

  ---@param min_level number @default=INFO
  return function(category, min_level)
    min_level = min_level or M.INFO
    local writer
    do
      local path, file = M.newfile(category, true)
      if file == nil then
        -- todo: close
        file = assert(io.open(path, "a"))
        facts.files[category].file = file
      end
      writer = BufferedWriter(file)
    end

    local function log(level, im)
      ---@param format string @lua's string.format, only %s is expected
      ---@param ... any @args used in format
      return function(format, ...)
        if level < min_level then return end

        writer.write(inteprete_msg(format, ...))
        writer.write("\n")
        if im then writer.flush() end
      end
    end

    return {
      debug = log(M.DEBUG, min_level <= M.DEBUG),
      info = log(M.INFO, min_level <= M.INFO),
      warn = log(M.WARN, true),
      err = log(M.ERROR, true),
    }
  end
end)()

return M
