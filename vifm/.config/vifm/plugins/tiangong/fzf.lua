local main
do
  local uid = assert(os.getenv("UID") or os.getenv("USER"), "unable to find out your uid")
  local in_tmux = os.getenv("TMUX") ~= nil

  ---@param category string
  ---@return string
  local function resolve_outfile(category) return string.format("/tmp/%s-vifm-%s-%s", uid, vifm.plugin.name, category) end

  ---@param script string
  ---@return string
  local function resolve_script_path(script) return string.format("%s/scripts/%s", vifm.plugin.path, script) end

  ---@param curview vifm.View
  ---@param outfile string
  local function goto_chosen_dir(curview, outfile)
    local file = assert(io.open(outfile, "r"))
    local chosen_dir = file:read("*a")
    assert(chosen_dir ~= "")
    file:close()
    curview:cd(chosen_dir)
  end

  if in_tmux then
    function main(script)
      local curview = vifm.currview()
      local outfile = resolve_outfile(script)
      local cmd = string.format("tmux display-popup -E %s --working-dir='%s' --out-file='%s'", resolve_script_path(script), curview.cwd, outfile)
      vifm.startjob({
        cmd = cmd,
        ---@param job vifm.Job
        onexit = function(job)
          local rc = job:exitcode()
          if rc ~= 0 then return vifm.sb.error(string.format("%s rc=%d", script, rc)) end
          goto_chosen_dir(curview, outfile)
        end,
      })
    end
  else
    function main(script)
      local curview = vifm.currview()
      local outfile = resolve_outfile(script)
      local cmd = string.format("%s --working-dir='%s' --out-file='%s'", resolve_script_path(script), curview.cwd, outfile)
      local rc = vifm.run({ cmd = cmd, pause = "never" })
      if rc ~= 0 then return vifm.sb.error(string.format("%s rc=%d", script, rc)) end
      goto_chosen_dir(curview, outfile)
    end
  end
end

--conctracts of scripts
--* args: --working-dir=? --out-file=?
--* rc: 0=ok, others=failed
--* tty: always

assert(vifm.keys.add({
  shortcut = "zd",
  modes = { "normal" },
  handler = function() main("zd.py") end,
  desc = "zd",
}))
assert(vifm.keys.add({
  shortcut = "zf",
  modes = { "normal" },
  handler = function() main("fd.py") end,
  desc = "cd 'fzf|subdir'",
}))
assert(vifm.keys.add({
  shortcut = "z.",
  modes = { "normal" },
  handler = function() vifm.startjob({ cmd = string.format("zd add '%s'", vifm.currview().cwd) }) end,
  desc = "z.",
}))

assert(vifm.cmds.add({
  name = "zd",
  description = "zd",
  minargs = 0,
  maxargs = 0,
  handler = function() main("zd.py") end,
}))
assert(vifm.cmds.add({
  name = "zf",
  description = "cd 'fzf|subdir'",
  minargs = 0,
  maxargs = 0,
  handler = function() main("fd.py") end,
}))
