local M = {}

local ex = require("infra.ex")
local fn = require("infra.fn")

-- todo: is there a global option for this?
local default_height = 10

---@param safe_code number
---@param cmd string
---@param ... string
local function safe_ex(safe_code, cmd, ...)
  local ok, ex_err = pcall(ex, cmd, ...)
  if ok then return end

  local safe_err = string.format("E%d", safe_code)
  if string.find(ex_err, safe_err) then return end
  error(ex_err)
end

---@param tabnr number?
---@return boolean,boolean
local function has_opened_ql(tabnr)
  -- todo: maybe an alternative impl: getqflist({winid = 0}).winid == 0
  tabnr = tabnr or vim.fn.tabpagenr()

  local qo, lo = false, false

  local info_iter = fn.filter(function(el)
    return el.tabnr == tabnr
  end, vim.fn.getwininfo())

  for info in info_iter do
    if info.quickfix == 1 then qo = true end
    if info.loclist == 1 then lo = true end
  end

  -- it's possible that `lo == qo == true` (see :help getwininfo)

  if lo then return false, true end
  if qo then return true, false end
  return false, false
end

---@param tabnr number?
---@param height number?
function M.toggle_qflist(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if qo then return ex("cclose") end
  -- exclusive to loclist
  if lo then ex("lclose") end
  ex(string.format("copen %d", height))
end

---@param tabnr number
---@param height number?
function M.toggle_loclist(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if lo then return ex("lclose") end
  -- exclusive to quickfix
  if qo then ex("cclose") end
  -- E776 is anonying
  safe_ex(776, string.format("lopen %d", height))
end

---@param tabnr number
---@param height number?
function M.open_loclist(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if lo then return end
  -- exclusive to quickfix
  if qo then ex("cclose") end
  -- E776 is anonying
  safe_ex(776, string.format("lopen %d", height))
end

---@param tabnr number?
---@param height number?
function M.open_qflist(tabnr, height)
  height = height or default_height
  local qo, lo = has_opened_ql(tabnr)
  if qo then return end
  -- exclusive to loclist
  if lo then ex("lclose") end
  ex(string.format("copen %d", height))
end

return M
