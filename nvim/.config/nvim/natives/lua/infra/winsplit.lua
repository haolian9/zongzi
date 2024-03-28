local api = vim.api

---@alias infra.winsplit.Side 'above'|'below'|'left'|'right'

local cmds = {
  above = { "split", "aboveleft" },
  below = { "split", "belowright" },
  left = { "vsplit", "aboveleft" },
  right = { "vsplit", "belowright" },
}

---split current window, put new window according to the 'side' param
---@param side infra.winsplit.Side
---@param path? string @a path or bufname
return function(side, path)
  local cmd, split = unpack(assert(cmds[side]))
  local args = { path }

  api.nvim_cmd({ cmd = cmd, mods = { split = split }, args = args }, { output = false })
end

