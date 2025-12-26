local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local mi = require("infra.mi")
local ni = require("infra.ni")

---@class infra.prefer.Descriptor
---@field private readopts table
---@field private writeopts table
local Descriptor = {
  __index = function(t, k) return ni.get_option_value(k, t.readopts) end,
  __newindex = function(t, k, v) return ni.set_option_value(k, v, t.writeopts) end,
}

do --.buf, .bo
  local cache = dictlib.CappedDict(256, true)

  ---@type fun(bufnr:integer):vim.bo
  function M.buf(bufnr)
    bufnr = mi.resolve_bufnr_param(bufnr)

    if not ni.buf_is_valid(bufnr) then
      cache[bufnr] = nil
      error(string.format("buf#%d does not exist", bufnr))
    end

    if cache[bufnr] == nil then
      cache[bufnr] = setmetatable({ --
        readopts = { buf = bufnr },
        writeopts = { buf = bufnr },
      }, Descriptor)
    end

    return cache[bufnr]
  end

  --getter or setter
  ---@param bufnr number
  ---@param k string
  function M.bo(bufnr, k, v)
    local descriptor = M.buf(bufnr)
    if v == nil then return descriptor[k] end
    descriptor[k] = v
  end
end

do --.win, .wo
  local cache = dictlib.CappedDict(256, true)

  ---@type fun(bufnr:integer):vim.wo
  function M.win(winid)
    winid = mi.resolve_winid_param(winid)

    if not ni.win_is_valid(winid) then
      cache[winid] = nil
      error(string.format("win#%d does not exist", winid))
    end

    if cache[winid] == nil then
      cache[winid] = setmetatable({ --
        readopts = { scope = "local", win = winid },
        writeopts = { scope = "local", win = winid },
      }, Descriptor)
    end

    return cache[winid]
  end

  --getter or setter
  ---@param winid number
  ---@param k string
  function M.wo(winid, k, v)
    local descriptor = M.win(winid)
    if v == nil then return descriptor[k] end
    descriptor[k] = v
  end
end

---define the default value for given option
M.def = assert(vim.o)

return M
