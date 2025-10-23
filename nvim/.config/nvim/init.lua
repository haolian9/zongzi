do
  local def = vim.go
  local global = vim.g
  local ex = function(cmd, ...) vim.api.nvim_cmd({ cmd = cmd, args = { ... } }, {}) end

  def.background = os.getenv("BGMODE") or "light"

  def.loadplugins = false -- so that no need to turn off {netrw,tar,zip,tutor,vimball,...} explictly
  global.loaded_shada_plugin = 1
  global.editorconfig = false

  ex("syntax", "off")

  ex("filetype", "plugin", "indent", "off")
  --no ftdetect neither, see bootstrap/filetype.lua
  ex("filetype", "off")
end

require("profiles").init()
require("batteries").install()

require("bootstrap")

require("batteries").load_rtp_plugins()
