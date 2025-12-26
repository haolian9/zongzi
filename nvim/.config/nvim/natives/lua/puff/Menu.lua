-- a drop-in replacement of vim.ui.select, just like tmux's display-menu
--
--design
--* keys are subset of [a-z]
--  * order is predicatable
--* each menu have its own buffer, multiple menus can appear at the same time
--* compact window layout, less eyes movement
--  * respects cursor position
--  * respects #choices and max(#each-choice)
--* dont reset window options and buffer lines initiatively

local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("puff.Menu")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local mi = require("infra.mi")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")

---@class puff.Menu.Spec
---@field key_pool puff.Keyring
---@field subject? string
---@field desc? string[]
---@field entries string[]
---@field entfmt fun(entry:string):string
---@field on_decide fun(entry:string?,index:number?) @index: 1-based
---@field colorful? boolean

local xmark_ns = ni.create_namespace("puff.menu.xmark")

do
  local hi = highlighter(0)

  hi("PuffMenuTitle", { bold = true })
  hi("PuffMenuDesc", {})

  if vim.go.background == "light" then
    hi("PuffMenuOption", { fg = 27, bold = true })
  else
    hi("PuffMenuOption", { fg = 33, bold = true })
  end
end

---@param spec puff.Menu.Spec
---@return integer bufnr
local function create_buf(spec)
  assert(#spec.entries <= #spec.key_pool.list, "no enough keys for puff.menu entries")

  local bufnr
  do
    local lines = {}
    if spec.subject ~= nil then table.insert(lines, spec.subject) end
    if spec.desc ~= nil then listlib.extend(lines, spec.desc) end
    for idx, ent in ipairs(spec.entries) do
      local key = assert(spec.key_pool.list[idx], "no more lhs is available")
      local line = string.format(" %s. %s", key, spec.entfmt(ent))
      table.insert(lines, line)
    end

    bufnr = Ephemeral({ namepat = "puff://menu/{bufnr}", handyclose = true }, lines)
  end

  if spec.colorful then
    local offset = 0
    if spec.subject ~= nil then
      mi.buf_highlight_line(bufnr, xmark_ns, 0, "PuffMenuTitle")
      offset = offset + 1
    end
    if spec.desc ~= nil then
      for lnum = offset, #spec.desc + offset do
        mi.buf_highlight_line(bufnr, xmark_ns, lnum, "PuffMenuDesc")
      end
      offset = offset + #spec.desc
    end
    for lnum = offset, offset + #spec.entries - 1 do
      local start, stop = 1, 2 -- ' %s.'
      ni.buf_set_extmark(bufnr, xmark_ns, lnum, start, { end_row = lnum, end_col = stop, hl_group = "PuffMenuOption" })
    end
  end

  do
    local index

    local bm = bufmap.wraps(bufnr)
    for _, key in ipairs(spec.key_pool.list) do
      bm.n(key, function()
        local n = assert(spec.key_pool:index(key), "unreachable: invalid key")
        -- not a present entry, do nothing
        if n > buflines.count(bufnr) then return jelly.info("no such option: %s", key) end
        index = n
        ni.win_close(0, false)
      end)
    end
    bm.n("<cr>", "<nop>")

    ni.create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        local choice = spec.entries[index]
        vim.schedule(function() -- to avoid 'Vim:E1159: Cannot split a window when closing the buffer'
          spec.on_decide(choice, choice ~= nil and index or nil)
        end)
      end,
    })
  end

  return bufnr
end

---@param spec puff.Menu.Spec
---@param bufnr integer
---@return integer winid
local function open_win(spec, bufnr)
  local winopts
  do
    local height = buflines.count(bufnr)

    local width = 0
    for _, len in unsafe.linelen_iter(bufnr, itertools.range(height)) do
      if len > width then width = len end
    end
    width = width + 1 -- 留白

    winopts = { relative = "cursor", row = 1, col = 0, width = width, height = height }
  end

  local winid = rifts.open.win(bufnr, true, winopts)

  do --cursor
    local lnum = 0
    if spec.subject then lnum = lnum + 1 end
    if spec.desc then lnum = lnum + #spec.desc end

    wincursor.go(winid, lnum, 0)
  end

  return winid
end

---@param spec puff.Menu.Spec
---@return integer winid
---@return integer bufnr
return function(spec)
  local bufnr = create_buf(spec)
  local winid = open_win(spec, bufnr)

  -- there is no easy way to hide the cursor, let it be there
  return winid, bufnr
end
