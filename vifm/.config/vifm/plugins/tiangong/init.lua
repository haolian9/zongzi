do
  local function swap_pannels(info)
    local _ = info
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
  local function joinpath(...) return table.concat({ ... }, "/") end

  local function main()
    if os.getenv("TMUX") == nil then return vifm.sb.error("requires tmux") end

    local a, basename
    do
      local view = vifm.currview()
      local ent = view:entry(view.currententry)
      basename = ent.name
      a = joinpath(view.cwd, basename)
    end

    --prefer the one with the same name, unless it exists not.

    local b
    do
      local view = vifm.otherview()
      local ent = view:entry(view.currententry)
      b = joinpath(view.cwd, basename)
      if not vifm.exists(b) then b = joinpath(view.cwd, ent.name) end
    end

    local cmd = string.format([[tmux new-window 'ni -d "%s" "%s"']], a, b)
    vifm.startjob({ cmd = cmd, iomode = "" })
  end

  vifm.cmds.add({ name = "diff", description = "diff the two files in both panes", minargs = 0, maxargs = 0, handler = main })
end

do
  local shell = os.getenv("SHELL") or "zsh"
  local in_tmux = os.getenv("TMUX") ~= nil

  local function rhs_shell(info)
    local _ = info
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

do
  assert(vifm.cmds.add({
    name = "newdir",
    description = "mkdir -p",
    minargs = 1,
    maxargs = -1,
    handler = function(info)
      --not an atomic operation when #info.argv > 1
      for _, path in ipairs(info.argv) do
        local ok = vifm.makepath(path)
        if not ok then vifm.sb.error(string.format("unable to mkdir %s", path)) end
      end
    end,
  }))

  assert(vifm.cmds.add({
    name = "new",
    description = "mkdir -p && touch",
    minargs = 1,
    maxargs = -1,
    handler = function(info)
      --not an atomic operation when #info.argv > 1
      for _, path in ipairs(info.argv) do
        local dir = string.match(path, ".+/")
        if dir then assert(vifm.makepath(dir)) end
        if not (dir and #dir == #path) then assert(io.open(path, "a")):close() end
      end
    end,
  }))
end

do
  assert(vifm.cmds.add({
    name = "umbra",
    description = "umbra .",
    minargs = 0,
    maxargs = 0,
    handler = function() vifm.startjob({ cmd = [[tmux splitw -h -l 25 umbra .]], iomode = "" }) end,
  }))

  assert(vifm.cmds.add({
    name = "sxiv",
    description = "sxiv .",
    minargs = 0,
    maxargs = 0,
    handler = function() vifm.startjob({ cmd = "sxiv .", iomode = "" }) end,
  }))
end

vifm.plugin.require("mpv")
vifm.plugin.require("fzf")

return {}
