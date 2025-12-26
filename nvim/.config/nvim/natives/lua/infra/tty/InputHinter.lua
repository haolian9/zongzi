local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local highlighter = require("infra.highlighter")
local listlib = require("infra.listlib")
local mi = require("infra.mi")
local ni = require("infra.ni")
local rifts = require("infra.rifts")

local floatwin_ns
do
  floatwin_ns = ni.create_namespace("hintline.floatwins")
  local hi = highlighter(floatwin_ns)
  if vim.go.background == "light" then
    hi("NormalFloat", { fg = 33 })
  else
    hi("NormalFloat", { fg = 33 })
  end
end

local xmark_ns = ni.create_namespace("hintline.xmarks")

---@class infra.tty.InputHinter
---@field private nchar integer
---@field private linger_time integer
---@field private bufnr integer
---@field private winid integer
---@field private chars string[]
---@field private progress integer
local InputHinter = {}
InputHinter.__index = InputHinter

---@param char string @ascii char
function InputHinter:feed(char)
  assert(#char == 1)
  if self.progress >= self.nchar then return end
  self.progress = self.progress + 1
  self.chars[self.progress] = char

  buflines.replace(self.bufnr, 0, table.concat(self.chars))
  mi.redraw_win(self.winid)
end

function InputHinter:clear()
  self.progress = 0
  self.chars = listlib.zeros(self.nchar, "_")

  buflines.replace(self.bufnr, 0, table.concat(self.chars))
  mi.redraw_win(self.winid)
end

function InputHinter:done()
  vim.defer_fn(function() ni.win_close(self.winid, true) end, self.linger_time)
end

---@param icon string
---@param nchar integer
---@param linger_time? integer @粘滞时间(ms); nil=500ms
---@return infra.tty.InputHinter
return function(icon, nchar, linger_time)
  linger_time = linger_time or 500

  local chars = listlib.zeros(nchar, "_")

  local bufnr
  do
    bufnr = Ephemeral({ namepat = "hintline://{bufnr}" })
    buflines.replace(bufnr, 0, table.concat(chars))
    ni.buf_set_extmark(bufnr, xmark_ns, 0, 0, {
      virt_text = { { icon, "Normal" }, { " " } },
      virt_text_pos = "inline",
      right_gravity = false,
    })
  end

  local winid = rifts.open.fragment(bufnr, false, {
    focusable = false,
    border = "none",
    relative = "editor",
  }, {
    height = 1,
    width = ni.strwidth(icon) + #" " + nchar,
    horizontal = "left",
    vertical = "bot",
    ns = floatwin_ns,
  })

  mi.redraw_win(winid)

  return setmetatable({
    nchar = nchar,
    linger_time = linger_time,
    bufnr = bufnr,
    winid = winid,
    chars = chars,
    progress = 0,
  }, InputHinter)
end
