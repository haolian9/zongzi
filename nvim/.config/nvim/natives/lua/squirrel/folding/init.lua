local M = {}

local jelly = require("infra.jellyfish")("squirrel.folding", "info")
local logging = require("infra.logging")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

local Resolver = require("squirrel.folding.Resolver")

local log = logging.newlogger("squirrel.folding", "info")

---@class squirrel.folding.state
local state = {
  ---@type { [number]: number }
  tick = {},
  ---@type { [number]: squirrel.folding.LineLevel }
  line_level = {},
  ---@param self squirrel.folding.state
  get = function(self, bufnr)
    if self.tick[bufnr] == nil then return end
    local now = ni.buf_get_changedtick(bufnr)
    if self.tick[bufnr] ~= now then
      self.tick[bufnr] = nil
      self.line_level[bufnr] = nil
      return
    end
    return self.line_level[bufnr]
  end,
  ---@param self squirrel.folding.state
  ---@param bufnr number
  ---@param tick number
  ---@param line_level squirrel.folding.LineLevel
  set = function(self, bufnr, tick, line_level)
    self.tick[bufnr] = tick
    self.line_level[bufnr] = line_level
  end,
}

---@return squirrel.folding.fold_expr
local function expr_handler(ft)
  local resolver = Resolver(ft)
  return function(lnum)
    local bufnr = ni.get_current_buf()
    local line_level = state:get(bufnr)
    if line_level == nil then
      line_level = resolver(bufnr)
      if line_level == nil then return 0 end
      local tick = ni.buf_get_changedtick(bufnr)
      state:set(bufnr, tick, line_level)
    end

    if line_level[lnum] ~= nil then return line_level[lnum] end
    local missing
    -- try at most 10 previous lines
    for i = lnum - 1, 0, -1 do
      local level = line_level[i]
      -- end of a tip node
      if level == 1 then
        missing = 0
        break
      end
      if level ~= nil then
        missing = level
        break
      end
    end
    if missing == nil then missing = 0 end
    line_level[lnum] = missing
    return missing
  end
end

---@type { [string]: squirrel.folding.fold_expr }
local exprs = setmetatable({}, {
  __index = function(t, ft)
    local handle = expr_handler(ft)
    rawset(t, ft, handle)
    return handle
  end,
})

function M.expr(row)
  local lnum = (row or vim.v.lnum) - 1
  local bufnr = ni.get_current_buf()
  local ft = prefer.bo(bufnr, "filetype")
  local handle = exprs[ft]
  if handle == nil then return "0" end
  local ok, result = xpcall(handle, debug.traceback, lnum)
  if ok then return tostring(result) end
  log.err("failed to resolve fold level: %s", result)
  --raise an error to let nvim stop evaluating
  jelly.fatal("RuntimeError", "failed to resolve fold level, see more in log")
end

return M
