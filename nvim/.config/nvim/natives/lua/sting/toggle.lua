--NB: `'cwin ' .. height` must be used for https://github.com/neovim/neovim/issues/21313

local M = {}

local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("sting.toggle", "info")
local strlib = require("infra.strlib")

local default_height = 10

---ignores `E776: No location list`
---@param cmd 'lwin'|'cwin'
---@param height? integer @nil=default_height
local function open(cmd, height)
  height = height or default_height
  local ok, err = pcall(ex, string.format("%s %d", cmd, height))
  if ok then return end
  if strlib.find(err, "E776") then return jelly.info("no available %s", cmd == "lwin" and "loclist" or "qflist") end
  error(err)
end

---@param tabnr? number
---@return boolean,boolean @qfwin opened, locwin opened
local function has_opened_ql(tabnr)
  tabnr = tabnr or vim.fn.tabpagenr()

  local qo, lo = false, false

  local info_iter = fn.filter(function(el) return el.tabnr == tabnr end, vim.fn.getwininfo())

  for info in info_iter do
    if info.quickfix == 1 then qo = true end
    if info.loclist == 1 then lo = true end
  end

  -- it's possible that `lo == qo == true` (see :help getwininfo)

  if lo then return false, true end
  if qo then return true, false end
  return false, false
end

---@param tabnr? number
---@param height? number
function M.qfwin(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if qo then return ex("cclose") end
  if lo then ex("lclose") end
  open("cwin", height)
  ex("wincmd", "J")
end

---@param tabnr? number
---@param height? number
function M.locwin(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if lo then return ex("lclose") end
  if qo then ex("cclose") end
  open("lwin", height)
end

---@param tabnr? number
---@param height? number
function M.open_locwin(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if lo then return end
  if qo then ex("cclose") end
  open("lwin", height)
end

---@param tabnr? number
---@param height? number
function M.open_qfwin(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if qo then return end
  if lo then ex("lclose") end
  open("cwin", height)
  ex("wincmd", "J")
end

return M
