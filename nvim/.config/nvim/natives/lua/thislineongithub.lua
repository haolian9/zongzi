local bufpath = require("infra.bufpath")
local Ephemeral = require("infra.Ephemeral")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("thislineongithub", "info")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")
local wincursor = require("infra.wincursor")

---@param root string @git root
---@param fpath string
---@return string
local function resolve_relative_fpath(root, fpath)
  local rel = fs.relative_path(root, fpath)
  assert(rel, "unreachable: no relative fpath")
  return rel
end

---@param uri string
---@return string? @username/project
local function resolve_namespace(uri)
  local prefix_len
  if strlib.startswith(uri, "git@github.com:") then --git@github.com:haolian9/neovim.git
    prefix_len = #"git@github.com:"
  elseif strlib.startswith(uri, "https://github.com/") then
    prefix_len = #"https://github.com"
  else
    return jelly.debug("unsupported platform: %s", uri)
  end

  local suffix_len
  if strlib.endswith(uri, ".git") then
    suffix_len = #".git"
  else
    suffix_len = 0
  end

  return assert(string.sub(uri, prefix_len + 1, -(suffix_len + 1)))
end

---@param root string @abspath
---@return {string:string} @{name: uri}
local function gather_remote_uri(root)
  local cp = subprocess.run("git", { args = { "remote", "--verbose" }, cwd = root }, "lines")
  assert(cp.exit_code == 0, "unreachable: no remote")

  local results = {}

  for line in cp.stdout do
    local start0, stop0 = string.find(line, "\t", 1, true)
    assert(start0 and stop0)
    local name = string.sub(line, 1, start0 - 1)
    local start1, stop1 = string.find(line, " ", stop0 + 1, true)
    assert(start1 and stop1)
    local uri = string.sub(line, stop0 + 1, start1 - 1)
    local use = string.sub(line, stop1 + 1)
    jelly.debug("name='%s' uri='%s', use='%s'", name, uri, use)
    if use == "(fetch)" then results[name] = uri end
  end

  return results
end

---@param root string @git root
---@return string
local function gather_commit(root)
  local cp = subprocess.run("git", { args = { "rev-parse", "HEAD" }, cwd = root }, "raw")
  assert(cp.exit_code == 0, "unreachable: rev-parse HEAD")
  local commit = cp.stdout()
  assert(commit ~= nil and commit ~= "", "unreachable: empty HEAD hash")
  return strlib.rstrip(commit)
end

---@param fpath string
---@return string?
local function gather_git_root(fpath)
  local cp = subprocess.run("git", { args = { "rev-parse", "--show-toplevel" }, cwd = fs.parent(fpath) }, "raw")
  if cp.exit_code ~= 0 then return jelly.warn("unable to resolve git root") end
  local root = cp.stdout()
  assert(root ~= nil and root ~= "", "unreachable: empty git_root")
  return strlib.rstrip(root)
end

return function()
  local fpath, cursor_row
  do
    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    fpath = bufpath.file(bufnr)
    if fpath == nil then return jelly.warn("no file associated to buf#%d", bufnr) end

    cursor_row = wincursor.row(winid)
  end

  local root = assert(gather_git_root(fpath))
  local rel_fpath = resolve_relative_fpath(root, fpath)
  local commit = gather_commit(root)

  local uris, hints = {}, {}
  for remote, repo_uri in pairs(gather_remote_uri(root)) do
    local ns = resolve_namespace(repo_uri)
    if ns == nil then goto continue end
    --sample: https://github.com/haolian9/fstr.nvim/blob/89c0f58273d89d6098f3154fa68ec7cf2d02f063/lua/fstr.lua#L4-L6
    table.insert(uris, string.format("https://github.com/%s/blob/%s/%s#L%d", ns, commit, rel_fpath, cursor_row))
    table.insert(hints, string.format("%s %s", remote, ns))
    ::continue::
  end
  if #uris == 0 then return jelly.info("no uri available") end

  local bufnr
  do
    bufnr = Ephemeral({ name = "thislineongithub://", handyclose = true }, hints)
    local bm = bufmap.wraps(bufnr)
    local function copy()
      local uri = assert(uris[wincursor.row()])
      vim.fn.setreg("+", uri)
      jelly.info("copied to system clipboard: %s", uri)
      ni.win_close(0, false)
    end
    bm.n("yy", copy)
    bm.n("<cr>", copy)
  end

  do
    local width, height = 0, 0
    for i = 1, #uris do
      width = math.max(width, #hints[i])
      height = height + 1
    end
    rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = width, height = height })
  end
end
