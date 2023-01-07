local api = vim.api
local jelly = require("infra.jellyfish")("scratch.bufcreate")

local function default_factory()
  return api.nvim_create_buf(false, true)
end

local function safe_delete(bufnr)
  local ok, err = xpcall(api.nvim_buf_delete, debug.traceback, bufnr, { force = true })
  if not ok then jelly.err("failed to delete buf#%d, err: %s", bufnr, err) end
  return ok
end

return function(cap)
  cap = cap or 5
  local factory = default_factory

  -- left in, right out
  -- {bufname: bufnr}
  local hold = {}

  local function get_or_create(bufname)
    assert(bufname ~= nil)

    local got = hold[bufname]
    if got ~= nil then return true, got end

    assert(#hold <= cap)
    if #hold == cap then safe_delete(table.remove(hold, #hold)) end
    local bufnr = factory()
    table.insert(hold, bufnr)

    return false, bufnr
  end

  local function clear()
    for _, bufnr in ipairs(hold) do
      safe_delete(bufnr)
    end
  end

  return {
    -- capacity, readonly
    cap = cap,
    get_or_create = get_or_create,
    clear = clear,
  }
end
