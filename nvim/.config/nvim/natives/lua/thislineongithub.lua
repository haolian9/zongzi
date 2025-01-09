local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("thislineongithub", "info")
local ni = require("infra.ni")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")
local wincursor = require("infra.wincursor")

return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local fpath = bufpath.file(bufnr)
  if fpath == nil then return jelly.info("no file associated to buf#%d", bufnr) end

  local git_root
  do
    local cp = subprocess.run("git", { args = { "rev-parse", "--show-toplevel" }, cwd = fs.parent(fpath) }, "raw")
    if cp.exit_code ~= 0 then return jelly.warn("unable to resolve git root") end
    git_root = cp.stdout()
    if not (git_root ~= nil and git_root ~= "") then return jelly.err("unreachable: empty git_root") end
    git_root = strlib.rstrip(git_root)
    jelly.debug("git_root=%s", git_root)
  end

  local line_uri
  do -- main
    local rel_fpath
    do
      rel_fpath = fs.relative_path(git_root, fpath)
      if rel_fpath == nil then return jelly.warn("unable to resolve relative fpath") end
      jelly.debug("rel_fpath=%s", rel_fpath)
    end

    local remote_uri
    do
      local cp = subprocess.run("git", { args = { "remote", "get-url", "origin" }, cwd = git_root }, "raw")
      if cp.exit_code ~= 0 then return jelly.warn("unable to resolve the remote uri") end
      remote_uri = cp.stdout()
      if not (remote_uri ~= nil and remote_uri ~= "") then return jelly.err("unreachable: empty remote_uri") end
      remote_uri = strlib.rstrip(remote_uri)
      jelly.debug("remote_uri=%s", remote_uri)
    end

    local namespace
    do
      local prefix_len
      if strlib.startswith(remote_uri, "git@github.com:") then --git@github.com:haolian9/neovim.git
        prefix_len = #"git@github.com:"
      elseif strlib.startswith(remote_uri, "https://github.com/") then
        prefix_len = #"https://github.com"
      else
        return jelly.warn("unsupported platform")
      end

      local suffix_len
      if strlib.endswith(remote_uri, ".git") then
        suffix_len = #".git"
      else
        suffix_len = 0
      end

      namespace = string.sub(remote_uri, prefix_len + 1, -(suffix_len + 1))
      jelly.debug("namespace=%s", namespace)
    end

    local commit
    do
      local cp = subprocess.run("git", { args = { "rev-parse", "HEAD" }, cwd = git_root }, "raw")
      if cp.exit_code ~= 0 then return jelly.warn("unable to resolve HEAD rev") end
      commit = cp.stdout()
      if not (commit ~= nil and commit ~= "") then return jelly.err("unreachable: empty HEAD hash") end
      commit = strlib.rstrip(commit)
    end

    local cursor_row = wincursor.row(winid)

    --sample: https://github.com/haolian9/fstr.nvim/blob/89c0f58273d89d6098f3154fa68ec7cf2d02f063/lua/fstr.lua#L4-L6
    line_uri = string.format("https://github.com/%s/blob/%s/%s#L%d", namespace, commit, rel_fpath, cursor_row)
  end

  return line_uri
end
