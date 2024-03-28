local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local bufmap = require("infra.keymap.buffer")
local rifts = require("infra.rifts")

local api = vim.api

local InputCollector
do
  ---@class puff.InputCollector
  ---@field bufnr integer
  ---@field value? string
  local Prototype = {}
  Prototype.__index = Prototype

  function Prototype:collect()
    assert(api.nvim_buf_line_count(self.bufnr) == 1)
    local lines = api.nvim_buf_get_lines(self.bufnr, 0, 1, false)
    self.value = lines[1]
  end

  ---@param bufnr integer
  ---@return puff.InputCollector
  function InputCollector(bufnr) return setmetatable({ bufnr = bufnr }, Prototype) end
end

---@param input? puff.InputCollector
---@param stop_insert? boolean @nil=false
local function make_rhs(input, stop_insert)
  return function()
    if input ~= nil then input:collect() end
    if stop_insert then ex("stopinsert") end
    api.nvim_win_close(0, false)
  end
end

---@class puff.input.Opts
---@field prompt? string
---@field default? string
---@field startinsert? boolean @nil=false
---@field wincall? fun(winid: integer, bufnr: integer) @timing: just created the win without setting any winopts
---@field bufcall? fun(bufnr: integer) @timing: just created the buf without setting any bufopts

---opts.{completion,highlight} are not supported
---@param opts puff.input.Opts
---@param on_complete fun(input_text?: string)
return function(opts, on_complete)
  local bufnr
  do
    local function namefn(nr) return string.format("input://%s/%d", opts.prompt, nr) end
    bufnr = Ephemeral({ modifiable = true, undolevels = 1, namefn = namefn }, opts.default and { opts.default } or nil)
    --todo: show prompt as inline extmark

    if opts.bufcall then opts.bufcall(bufnr) end

    local input = InputCollector(bufnr)
    do
      local bm = bufmap.wraps(bufnr)
      bm.i("<cr>", make_rhs(input, true))
      bm.i("<c-c>", make_rhs(nil, true))
      bm.n("<cr>", make_rhs(input))
      local rhs_noinput = make_rhs()
      bm.n("q", rhs_noinput)
      bm.n("<esc>", rhs_noinput)
      bm.n("<c-[>", rhs_noinput)
      bm.n("<c-]>", rhs_noinput)
    end
    api.nvim_create_autocmd("bufwipeout", { buffer = bufnr, once = true, callback = function() on_complete(input.value) end })
  end

  local winid
  do
    local width = opts.default and math.max(#opts.default, 50) or 50
    local winopts = { relative = "cursor", row = 1, col = 2, width = width, height = 1 }
    winid = rifts.open.win(bufnr, true, winopts)
    if opts.default then api.nvim_win_set_cursor(winid, { 1, #opts.default }) end
    if opts.wincall then opts.wincall(winid, bufnr) end
  end

  if opts.startinsert then ex("startinsert") end
end
