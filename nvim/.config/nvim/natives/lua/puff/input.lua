local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("puff.input", "info")
local bufmap = require("infra.keymap.buffer")
local LRU = require("infra.LRU")
local mi = require("infra.mi")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")

local InputCollector
do
  ---@class puff.InputCollector
  ---@field bufnr integer
  ---@field value? string
  local Impl = {}
  Impl.__index = Impl

  function Impl:collect()
    assert(buflines.count(self.bufnr) == 1)
    self.value = buflines.line(self.bufnr, 0)
  end

  ---@param bufnr integer
  ---@return puff.InputCollector
  function InputCollector(bufnr) return setmetatable({ bufnr = bufnr }, Impl) end
end

---@param input? puff.InputCollector
---@param stop_insert boolean
local function make_closewin_rhs(input, stop_insert)
  return function()
    if input ~= nil then input:collect() end
    if stop_insert then mi.stopinsert() end
    ni.win_close(0, false)
  end
end

---@class puff.input.Opts
---@field prompt? string @vim.ui.input
---@field default? string @vim.ui.input
---@field icon? string @it will be placed in the beginning of the input line
---@field startinsert? 'i'|'a'|'I'|'A'|false @nil=false
---@field wincall? fun(winid: integer, bufnr: integer) @timing: just created the win without setting any winopts
---@field bufcall? fun(bufnr: integer) @timing: post created the buffer, pre bound keymaps
---@field remember? string @remember the last input as the given namespace as the .default when it's nil

---@type {[string]: string}
local last_inputs = LRU(32)

---NB: opts.{completion,highlight} are not supported
---@param opts puff.input.Opts
---@param on_complete fun(input_text?: string) @note: nil is not ""
---@return integer winid
---@return integer bufnr
return function(opts, on_complete)
  if opts.default == nil and opts.remember ~= nil then
    local last_input = last_inputs[opts.remember]
    if last_input ~= nil then opts.default = last_input end
  end
  --treat default="" as nil to reduce unnecessary calls
  if opts.default == "" then opts.default = nil end

  local bufnr
  do
    local function namefn(nr) return string.format("puff://input/%s/%d", opts.prompt, nr) end
    local lines = opts.default ~= nil and { opts.default } or nil
    bufnr = Ephemeral({ modifiable = true, undolevels = 1, namefn = namefn }, lines)

    if opts.icon then
      local ns = ni.create_namespace("puff:input")
      ni.buf_set_extmark(bufnr, ns, 0, 0, {
        virt_text = { { opts.icon, "Normal" }, { " " } },
        virt_text_pos = "inline",
        right_gravity = false,
      })
    end

    --ATTENTION: potential race condition between opts.bufcall and the following bm()
    if opts.bufcall then opts.bufcall(bufnr) end

    local input = InputCollector(bufnr)

    ni.create_autocmd("bufwipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        if opts.remember ~= nil then last_inputs[opts.remember] = input.value end
        vim.schedule(function() -- to avoid 'Vim:E1159: Cannot split a window when closing the buffer'
          on_complete(input.value)
        end)
      end,
    })

    local bm = bufmap.wraps(bufnr)

    bm.i("<cr>", make_closewin_rhs(input, true))
    bm.i("<c-c>", make_closewin_rhs(nil, true))
    bm.n("<cr>", make_closewin_rhs(input, false))

    do
      local rhs = make_closewin_rhs(nil, false)
      bm.n("q", rhs)
      bm.n("<esc>", rhs)
      bm.n("<c-[>", rhs)
      bm.n("<c-]>", rhs)
    end

    do
      local function rhs() jelly.info("o/O/yy has no effect here") end
      bm.n("o", rhs)
      bm.n("O", rhs)
      bm.n("yy", rhs)
      --concern: yyp
    end
  end

  local winid
  do
    local width = opts.default and math.max(#opts.default, 50) or 50
    local winopts = { relative = "cursor", row = 1, col = 2, width = width, height = 1 }
    winid = rifts.open.win(bufnr, true, winopts)
    if opts.default then wincursor.go(winid, 0, #opts.default) end
    if opts.wincall then opts.wincall(winid, bufnr) end
  end

  if opts.startinsert then feedkeys(opts.startinsert, "n") end

  return winid, bufnr
end
