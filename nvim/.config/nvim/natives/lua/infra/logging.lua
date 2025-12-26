local strfmt = require("infra._strfmt")
local coreutils = require("infra.coreutils")

local ropes = require("string.buffer")

local M = {}

---log level
---@type {[string|integer]: integer}
local ll = {}
do
  for _, name in ipairs({ "DEBUG", "INFO", "WARN", "ERROR" }) do
    local val = vim.log.levels[name]
    ll[name] = val
    ll[string.lower(name)] = val
    ll[val] = val
  end
end

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

---@param category string
---@param ensure_created ?boolean @nil=true
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

do
  ---@param file file*
  ---@param bufsize? integer @nil=4096
  local function BufferedWriter(file, bufsize)
    bufsize = bufsize or 4096

    local stash = ropes.new(bufsize)

    local function flush()
      if #stash == 0 then return end
      file:write(stash:get())
      file:flush()
    end

    ---@param str string
    local function write(str)
      stash:put(str)
      if #stash >= bufsize then flush() end
    end

    return {
      write = write,
      flush = flush,
    }
  end

  -- NB: caller should decide when to close the fd of logfile
  ---@param min_level string? @{debug,info,warn,error}; nil=info
  function M.newlogger(category, min_level)
    ---@diagnostic disable-next-line: cast-local-type
    min_level = ll[min_level or "info"]

    local function open_writer()
      local path, file = M.newfile(category, true)
      if file == nil then
        file = assert(io.open(path, "a"))
        facts.files[category].file = file
      end
      return BufferedWriter(file)
    end

    local writer

    ---@param level integer
    ---@param flush_after_log boolean
    ---@return fun(format: string, ...)
    local function log(level, flush_after_log)
      ---@diagnostic disable-next-line: unused-local
      if level < min_level then return function(format, ...) end end

      return function(format, ...)
        if writer == nil then writer = open_writer() end

        writer.write(strfmt(format, ...))
        writer.write("\n")
        if flush_after_log then writer.flush() end
      end
    end

    return {
      debug = log(ll.debug, min_level <= ll.debug),
      info = log(ll.info, min_level <= ll.info),
      warn = log(ll.warn, true),
      err = log(ll.error, true),
    }
  end
end

return M
