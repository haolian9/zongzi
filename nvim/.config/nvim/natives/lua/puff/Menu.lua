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
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("puff.Menu")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")

---@class puff.Menu.Spec
---@field key_pool puff.KeyPool
---@field subject? string
---@field desc? string[]
---@field entries string[]
---@field entfmt fun(entry:string):string
---@field on_decide fun(entry:string?,index:number?) @index: 1-based

---@param spec puff.Menu.Spec
---@return integer bufnr
local function create_buf(spec)
  local lines = {}
  do
    if spec.subject ~= nil then table.insert(lines, spec.subject) end
    if spec.desc ~= nil then listlib.extend(lines, spec.desc) end

    local key_iter = spec.key_pool:iter()
    for _, ent in ipairs(spec.entries) do
      local key = assert(key_iter(), "no more lhs is available")
      local line = string.format(" %s. %s", key, spec.entfmt(ent))
      table.insert(lines, line)
    end
  end

  local bufnr = Ephemeral({ namepat = "menu://{bufnr}", handyclose = true }, lines)

  do
    local choice

    local bm = bufmap.wraps(bufnr)
    for key in spec.key_pool:iter() do
      bm.n(key, function()
        local n = assert(spec.key_pool:index(key), "unreachable: invalid key")
        -- not a present entry, do nothing
        if n > buflines.count(bufnr) then return jelly.info("no such option: %s", key) end
        choice = n
        ni.win_close(0, false)
      end)
    end

    bm.n("<cr>", "<nop>")

    ni.create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        vim.schedule(function() -- to avoid 'Vim:E1159: Cannot split a window when closing the buffer'
          spec.on_decide(spec.entries[choice], choice)
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
