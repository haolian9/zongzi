---@return string|nil
local function getenv(key)
  -- todo: replace with os.getenv
  assert(#key > 0 and string.sub(key, 1, 1) == "$")
  local val = vifm.expand(key)
  if val == key or val == "" then return end
  return val
end

do
  local function swap_pannels(info)
    _ = info
    local v0 = vifm.currview()
    local v1 = vifm.otherview()
    local v0_cwd = v0.cwd
    local v1_cwd = v1.cwd
    assert(v0:cd(v1_cwd))
    assert(v1:cd(v0_cwd))
  end

  -- or <c-w>-x
  assert(vifm.cmds.add({ name = "swap", maxargs = 0, handler = swap_pannels, description = "swap the two pannels" }))
end

do
  local shell = getenv("$SHELL") or "zsh"
  local in_tmux = getenv("$TMUX") ~= nil

  local function rhs_shell(info)
    _ = info
    if not in_tmux then
      vifm.run({ cmd = shell })
    else
      local v = vifm.currview()
      local cmd = string.format("tmux splitw -v -l 15 -c '%s' %s", v.cwd, shell)
      vifm.startjob({ cmd = cmd, iomode = "" })
    end
  end

  assert(vifm.keys.add({ shortcut = "`", modes = { "normal" }, handler = rhs_shell }))
  assert(vifm.keys.add({ shortcut = "s", modes = { "normal" }, handler = rhs_shell }))
end

return {}
