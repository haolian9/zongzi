local M = {}

local buflines = require("infra.buflines")
local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("digits.cmds.diffhunks")
local ni = require("infra.ni")

local create_git = require("digits.create_git")
local sting = require("sting")

---@param git? digits.Git
---@param winid? integer
function M.setloclist(git, winid)
  git = git or create_git()
  winid = winid or ni.get_current_win()

  local bufnr = ni.win_get_buf(winid)

  local args = { "--no-pager", "show" }
  do
    local abs = bufpath.file(bufnr)
    if abs == nil then return jelly.debug("no file associated to buf=#d in git repo", bufnr) end
    local path = fs.relative_path(git.root, abs)
    --no need to check if this path exists or not, as it can be deleted
    --`git diff --porcelain=v1 -- {file}`
    table.insert(args, string.format("HEAD:%s", path))
  end

  do
    local old = itertools.join(git:run(args), "\n")
    local now = buflines.joined(bufnr)
    local shelf = sting.location.shelf(winid, "diffhunks")
    shelf:reset()
    vim.diff(now, old, {
      on_hunk = function(start_a, count_a, start_b, count_b)
        jelly.debug("a=%d,%d, b=%d,%d", start_a, count_a, start_b, count_b)
        assert(not (count_a == 0 and count_b == 0))
        local text
        if count_b == 0 then
          text = string.format("++ %d", count_a)
        elseif count_a == 0 then
          text = string.format("-- %d", count_b)
        else
          text = string.format("~~ %d->%d", count_b, count_a)
        end
        shelf:append({ bufnr = bufnr, lnum = start_a, col = 0, text = text })
      end,
    })
    shelf:feed_vim(true, false)
  end
end

return M
