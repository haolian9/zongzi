local M = {}

local Augroup = require("infra.Augroup")
local dictlib = require("infra.dictlib")

local api = vim.api

---@class infra.prefer.Descriptor
---@field private opts {buf: number?, win: number?} @ used for api.nvim_{g,s}et_option_value
local Descriptor = {
  __index = function(t, k) return api.nvim_get_option_value(k, t.opts) end,
  __newindex = function(t, k, v) return api.nvim_set_option_value(k, v, t.opts) end,
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
  local aug = Augroup("prefer://")
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

M.buf = new_local_descriptor("buf", api.nvim_buf_is_valid)
M.win = new_local_descriptor("win", api.nvim_win_is_valid)

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
      return M.bo(api.nvim_get_current_buf(), k)
    end,
    __newindex = function(_, k, v)
      assert(type(k) == "string")
      M.bo(api.nvim_get_current_buf(), k, v)
    end,
  })
  vim.wo = setmetatable({}, {
    __index = function(_, k)
      if type(k) == "number" then return M.win(k) end
      return M.wo(api.nvim_get_current_win(), k)
    end,
    __newindex = function(_, k, v)
      assert(type(k) == "string")
      M.wo(api.nvim_get_current_win(), k, v)
    end,
  })

  vim.o = setmetatable({}, {
    __index = function() error("use vim.{g,b,w}o instead") end,
    __newindex = function() error("use vim.{g,b,w}o instead") end,
  })
end

return M
