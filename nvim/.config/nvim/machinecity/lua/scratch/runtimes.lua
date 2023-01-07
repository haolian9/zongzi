-- in my test, runtime file need to execute in every buffer

local M = {}

local api = vim.api

local jelly = require("infra.jellyfish")("scratch.runtimes")

local loaded = {}

M.source = function(file)
  if loaded[file] ~= nil then
    jelly.debug("refuse to source %s again", file)
  else
    api.nvim_command(string.format("runtime %s", file))
    loaded[file] = true
    jelly.debug("fresh source %s", file)
  end
end

M.source_again = function(file)
  api.nvim_command(string.format("runtime %s", file))
  loaded[file] = (loaded[file] or 0) + 1
  jelly.debug("sourced %s %d times", file, loaded[file])
end

return M
