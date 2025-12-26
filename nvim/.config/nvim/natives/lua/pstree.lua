local M = {}

local buflines = require("infra.buflines")
local bufopen = require("infra.bufopen")
local Ephemeral = require("infra.Ephemeral")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("pstree")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local subprocess = require("infra.subprocess")

-- used for &foldexpr
-- :h fold-expr
---@return number @fold level
function M.fold(row)
  local curline = assert(buflines.line(0, row - 1))

  if curline == "" then return 0 end

  local indent = 0
  do
    local index = 1
    local spaces = 0
    while true do
      local char = string.sub(curline, index, index)
      if char == " " then
        spaces = spaces + 1
        if spaces == 4 then
          spaces = 0
          indent = indent + 1
        end
      elseif char == "|" then
        assert(spaces == 2 or spaces == 3)
        local next_char = string.sub(curline, index + 1, index + 1)
        index = index + 1
        if next_char == " " then
          spaces = 0
          indent = indent + 1
        elseif next_char == "-" then
          spaces = 0
          indent = indent + 1
        else
          error(string.format("unreachable: %s%s", char, next_char))
        end
      elseif char == "`" then
        assert(spaces == 2 or spaces == 3)
        local next_char = string.sub(curline, index + 1, index + 1)
        index = index + 1
        if next_char == "-" then
          spaces = 0
          indent = indent + 1
        else
          error(string.format("unreachable: %s%s", char, next_char))
        end
      else
        break
      end
      index = index + 1
    end
  end

  return indent
end

local function rhs_hover()
  local pid
  do
    local line = ni.get_current_line()
    -- blank line, it's possible
    if line == "" then return end
    -- a thread
    if string.find(line, "-{[%w-_]+},") ~= nil then return end
    local matched = string.match(line, ",%d+")
    if matched == nil then error(string.format('failed to find pid in line "%s"', line)) end
    pid = tonumber(string.sub(matched, 2))
  end
  assert(pid ~= nil)

  local bufnr = Ephemeral({ namepat = "pstree://hover/{bufnr}", handyclose = true })

  local chunks = {}
  local stdout_closed = false
  subprocess.spawn("ps", { args = { "-orss,trs,drs,vsz,cputime,tty,lstart", tostring(pid) } }, function(data)
    if data ~= nil then table.insert(chunks, data) end
    stdout_closed = true
  end, function(exit_code)
    assert(stdout_closed)
    if exit_code ~= 0 then return jelly.err("unable to get process info of %d, exit=%d", pid, exit_code) end
    local lines = itertools.tolist(subprocess.iter_lines(chunks))
    vim.schedule(function() buflines.replaces_all(bufnr, lines) end)
  end)

  do
    local width, height = 70, 2 --based on the output of ps
    local winopts = { relative = "cursor", width = width, height = height, row = 1, col = 0 }
    rifts.open.win(bufnr, true, winopts)
  end
end

---@param extra table @extra params for pstree command
---@param open_mode? infra.bufopen.Mode
function M.run(extra, open_mode)
  extra = extra or {}
  open_mode = open_mode or "tab"

  local args = { "-A", "-acnpt" }
  listlib.extend(args, extra)

  local bufnr = Ephemeral({ namepat = "pstree://{bufnr}" })
  bufmap(bufnr, "n", "K", rhs_hover)

  local chunks = {}
  local stdout_closed = false
  subprocess.spawn("/usr/bin/pstree", { args = args }, function(data)
    if data ~= nil then return table.insert(chunks, data) end
    stdout_closed = true
  end, function(exit_code)
    assert(stdout_closed)
    if exit_code ~= 0 then return jelly.err("unable to get pstree", exit_code) end
    local lines = itertools.tolist(subprocess.iter_lines(chunks))
    vim.schedule(function() buflines.replaces_all(bufnr, lines) end)
  end)

  do --win setup
    bufopen(open_mode, bufnr)
    local winid = ni.get_current_win()
    local wo = prefer.win(winid)
    wo.foldenable = true
    wo.foldmethod = "expr"
    wo.foldexpr = [[v:lua.require'pstree'.fold(v:lnum)]]
  end
end

return M
