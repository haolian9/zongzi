-- for notification

---@param opts {source: string}
local function provider(msg, level, opts)
  if true then return vim.notify(msg, level, opts) end

  require("cthulhu").notify.critical(opts.source, msg)
end

---@alias notifier fun(format: string, ...: any)

---@param source string @who sent this message
---@return notifier
local function notify(source, level, min_level)
  assert(source and level and min_level)
  if level < min_level then return function() end end

  return function(format, ...)
    local opts = { source = source }
    if select("#", ...) ~= 0 then return provider(string.format(format, ...), level, opts) end
    assert(format ~= nil, "missing format")
    if string.find(format, "%%s") == nil then return provider(format, level, opts) end
    error("unmatched args for format")
  end
end

---@param source string
---@param min_level number? @vim.log.levels.*; default=INFO
return function(source, min_level)
  assert(source ~= nil)
  local lvls = vim.log.levels
  min_level = min_level or lvls.INFO

  return {
    debug = notify(source, lvls.DEBUG, min_level),
    info = notify(source, lvls.INFO, min_level),
    warn = notify(source, lvls.WARN, min_level),
    err = notify(source, lvls.ERROR, min_level),
  }
end
