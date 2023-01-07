local M = {}

local api = vim.api

local function load_plugins_rtp()
  local path = string.format("%s/%s", vim.fn.stdpath("data"), "viz.json")
  local file = assert(io.open(path, "r"))
  local data = file:read("*a")
  file:close()
  -- {pre: [str], post: [str]}
  return vim.json.decode(data)
end

local function merge_rtp(plugins_rtp)
  -- order:
  -- * viz.plugins.pre
  -- * vim.native.{pre,after}
  -- * viz.plugins.after
  local final = {}
  for _, path in ipairs(plugins_rtp.pre) do
    table.insert(final, path)
  end
  for path in vim.gsplit(vim.o.rtp, ",", true) do
    table.insert(final, path)
  end
  for _, path in ipairs(plugins_rtp.post) do
    table.insert(final, path)
  end
  return final
end

function M.setup()
  local rtp = merge_rtp(load_plugins_rtp())
  api.nvim_set_option("rtp", table.concat(rtp, ","))
end

return M
