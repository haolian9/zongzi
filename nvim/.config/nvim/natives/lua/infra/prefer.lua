local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local ni = require("infra.ni")

---@class infra.prefer.Descriptor
---@field private opts {buf: number?, win: number?} @ used for ni.{g,s}et_option_value
local Descriptor = {
  __index = function(t, k) return ni.get_option_value(k, t.opts) end,
  __newindex = function(t, k, v) return ni.set_option_value(k, v, t.opts) end,
}

local cache = {
  ---@type {[number]: infra.prefer.Descriptor}
  buf = dictlib.CappedDict(256, true),
  ---@type {[number]: infra.prefer.Descriptor}
  win = dictlib.CappedDict(256, true),
}

---@param scope 'buf'|'win'
---@param checker fun(handle: number): boolean
local function new_local_descriptor(scope, checker)
  ---@param handle number
  return function(handle)
    if not checker(handle) then error(string.format("%s#%d does not exist", scope, handle)) end
    if cache[scope][handle] == nil then cache[scope][handle] = setmetatable({ opts = { [scope] = handle } }, Descriptor) end
    return cache[scope][handle]
  end
end

do
  local aug = augroups.Augroup("prefer://")
  aug:once("User", {
    pattern = "bootstrapped",
    callback = function()
      M.def = setmetatable({}, {
        __index = function() error("not available after bootstrapped") end,
        __newindex = function() error("not available after bootstrapped") end,
      })
    end,
  })
end

---@type fun(bufnr: integer): vim.bo
M.buf = new_local_descriptor("buf", ni.buf_is_valid)
---@type fun(winid: integer): vim.wo
M.win = new_local_descriptor("win", ni.win_is_valid)

--getter or setter
---@param bufnr number
---@param k string
function M.bo(bufnr, k, v)
  local descriptor = M.buf(bufnr)
  if v == nil then return descriptor[k] end
  descriptor[k] = v
end

--getter or setter
---@param winid number
---@param k string
function M.wo(winid, k, v)
  local descriptor = M.win(winid)
  if v == nil then return descriptor[k] end
  descriptor[k] = v
end

---define the default value for given option
M.def = assert(vim.o)

function M.monkeypatch()
  vim.bo = setmetatable({}, {
    __index = function(_, k)
      if type(k) == "number" then return M.buf(k) end
      return M.bo(ni.get_current_buf(), k)
    end,
    __newindex = function(_, k, v)
      assert(type(k) == "string")
      M.bo(ni.get_current_buf(), k, v)
    end,
  })
  vim.wo = setmetatable({}, {
    __index = function(_, k)
      if type(k) == "number" then return M.win(k) end
      return M.wo(ni.get_current_win(), k)
    end,
    __newindex = function(_, k, v)
      assert(type(k) == "string")
      M.wo(ni.get_current_win(), k, v)
    end,
  })

  ---sadly, it's impossible to avoid vim.o being called in nvim's runtime, see vim.lsp.util
  -- vim.o = setmetatable({}, {
  --   __index = function(_, key) error(string.format("trying to access %s, use vim.{g,b,w}o instead", key)) end,
  --   __newindex = function(_, key, val) error(string.format("trying to set %s=%s, use vim.{g,b,w}o instead", key, val)) end,
  -- })
  ---
  ---as a compromise, link it to vim.go
  vim.o = vim.go
end

return M
