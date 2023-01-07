-- design choices
-- * cache would have big performance improvement
--   * cursor position updates on every move
--

local M = {}

local api = vim.api
local unsafe = require("infra.unsafe")
local bufdispname = require("infra.bufdispname")

local function repeat_cmds()
  local mode = api.nvim_get_mode()
  -- only show in normal mode
  if mode.mode ~= "n" then return "" end

  local cmds = unsafe.get_inserted() or ""
  if #cmds == 0 then return "" end

  -- when exit insert mode, escape often occurs in the tail
  for i = #cmds, 1, -1 do
    local code = string.byte(string.sub(cmds, i, i))
    if code == 0x1b then return ".<ins>" end
  end

  -- .d:lua require'nvim-treesitter.textobjects.select'.select_textobject('@function.inner', 'o')\n
  do
    local found = string.find(cmds, ":lua")
    if found ~= nil then return string.format(".%s<lua>", string.sub(cmds, 1, found - 1)) end
  end

  -- d:cal <SNR>29_HandleTextObjectMapping(1, 0, 0, [line("."), line("."), col("."), col(".")])\n
  do
    local found = string.find(cmds, ":cal")
    if found ~= nil then return string.format(".%s<cal>", string.sub(cmds, 1, found - 1)) end
  end

  return "." .. cmds
end

---@class statusline.builder.record
---@field tick number
---@field parts string[]

---@class statusline.builder
local builder = {
  --{bufnr: record}
  ---@type {[number]: statusline.builder.record}
  cache = {},
}

do
  --return (record, have_cached_before_get)
  ---@return statusline.builder.record, boolean
  function builder:_get(bufnr)
    if self.cache[bufnr] then return self.cache[bufnr], true end
    self.cache[bufnr] = { tick = 0, parts = {} }
    return self.cache[bufnr], false
  end

  ---@return string
  function builder:_fname(bufnr)
    local bufname = api.nvim_buf_get_name(bufnr)
    return bufdispname.blank(bufnr, bufname) or bufdispname.proto(bufnr, bufname) or bufdispname.relative_stem(bufnr, bufname)
  end

  ---@return string?
  function builder:_buf_status(bufnr)
    if vim.bo[bufnr].modified then return "*" end
  end

  ---@return string
  function builder:_alt_fname(bufnr)
    -- no alt fname
    if bufnr == -1 then return "" end
    local bufname = api.nvim_buf_get_name(bufnr)
    return bufdispname.blank(bufnr, bufname) or bufdispname.proto(bufnr, bufname) or bufdispname.stem(bufnr, bufname)
  end

  function builder:build(fresh)
    local bufnr = api.nvim_get_current_buf()
    local alt_bufnr = vim.fn.bufnr('#')

    local cache, have_cached_before = self:_get(bufnr)
    local tick = api.nvim_buf_get_changedtick(bufnr)
    local have_changed = tick ~= cache.tick

    if fresh then have_changed = true end

    local parts

    -- :h statusline
    local left = "%<"
    local center = "%="

    if not have_cached_before or have_changed then
      parts = {}
      local function add(fmt, ...)
        table.insert(parts, string.format(fmt, ...))
      end

      local dot = repeat_cmds()

      local f0 = self:_fname(bufnr)
      local buf_status = self:_buf_status(bufnr)
      local f1 = bufnr ~= alt_bufnr and self:_alt_fname(alt_bufnr) or ""

      -- left part
      add([[%%#StatusLineRepeat#%s%s]], left, dot)
      -- center part
      add([[%%#StatusLineSpan#%s]], center)
      add([[%%#StatusLineFilePath#%s]], f0)
      if buf_status then add([[%%#StatusLineBufStatus#%s]], buf_status) end
      add([[%%#StatusLineSpan#%s%s]], left, " ")
      add([[%%#StatusLineAltFile#%s%s]], left, f1)
      add([[%%#StatusLineSpan#%s]], center)
      -- right part
      add([[%%#StatusLineCursor#%s]], "%c,%l/%L")
    else
      parts = cache.parts
      local f1 = bufnr ~= alt_bufnr and self:_alt_fname(alt_bufnr) or ""
      -- magic position here
      parts[#parts - 2] = string.format([[%%#StatusLineAltFile#%s%s]], left, f1)
    end

    self.cache[bufnr].tick = tick
    self.cache[bufnr].parts = parts

    return table.concat(parts, "")
  end
end

---@param fresh boolean @nil=false
function M.render(fresh)
  if fresh == nil then fresh = false end
  return builder:build(fresh)
end

function M.need_update(bufnr)
  builder.cache[bufnr] = nil
end

return M
