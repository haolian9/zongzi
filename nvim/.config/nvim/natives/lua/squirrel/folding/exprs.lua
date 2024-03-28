local api = vim.api
local level_resolver = require("squirrel.folding.level_resolver")

---@class squirrel.folding.state
local state = {
  ---@type { [number]: number }
  tick = {},
  ---@type { [number]: squirrel.folding.LineLevel }
  line_level = {},
  ---@param self squirrel.folding.state
  get = function(self, bufnr)
    if self.tick[bufnr] == nil then return end
    local now = api.nvim_buf_get_changedtick(bufnr)
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
  local resolver = level_resolver(ft)
  return function(lnum)
    lnum = lnum - 1
    local bufnr = api.nvim_get_current_buf()
    local line_level = state:get(bufnr)
    if line_level == nil then
      line_level = resolver(bufnr)
      local tick = api.nvim_buf_get_changedtick(bufnr)
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
return setmetatable({}, {
  __index = function(t, key)
    t[key] = expr_handler(key)
    return t[key]
  end,
})
