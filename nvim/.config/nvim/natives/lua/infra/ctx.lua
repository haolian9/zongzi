local M = {}

local dictlib = require("infra.dictlib")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

---@param bufnr integer
---@param logic fun()
function M.noundo(bufnr, logic)
  local bo = prefer.buf(bufnr)
  local orig = bo.undolevels
  bo.undolevels = -1
  local ok, err = xpcall(logic, debug.traceback)
  bo.undolevels = orig
  if not ok then error(err) end
end

---@param bufnr integer
---@param logic fun()
function M.undoblock(bufnr, logic)
  --no need to wrap buf_set_lines with `undojoin`, as it will not close the undo block
  local bo = prefer.buf(bufnr)
  --close previous undo block
  local orig = bo.undolevels
  local ok, err = xpcall(logic, debug.traceback)
  --close this undo block
  bo.undolevels = orig
  if not ok then error(err) end
end

---@param bufnr integer
---@param logic fun()
function M.modifiable(bufnr, logic)
  local bo = prefer.buf(bufnr)

  if bo.modifiable then return logic() end

  bo.modifiable = true
  local ok, result = xpcall(logic, debug.traceback)
  bo.modifiable = false

  if not ok then error(result) end
  return result
end

---for buf_set_lines/text as them always disorder the cursor
---@param winid integer
---@param logic fun(): any
---@return any @depends on logic()
function M.winview(winid, logic)
  local view = M.win(winid, function() return vim.fn.winsaveview() end)
  local ok, result = xpcall(logic, debug.traceback)
  M.win(winid, function() vim.fn.winrestview(view) end)

  if not ok then error(result) end
  return result
end

---do to all the windows being attached of a bufnr
---@param bufnr integer
---@param logic fun(): any
---@return any @depends on logic()
function M.bufviews(bufnr, logic)
  ---@type {[integer]: any} @{winid: view}
  local views = {}
  do
    local bufinfo = assert(vim.fn.getbufinfo(bufnr)[1])
    for _, winid in ipairs(bufinfo.windows) do
      views[winid] = M.win(winid, function() return vim.fn.winsaveview() end)
    end
  end

  local ok, result = xpcall(logic, debug.traceback)

  for winid, view in pairs(views) do
    M.win(winid, function() vim.fn.winrestview(view) end)
  end

  if not ok then error(result) end
  return result
end

do
  local function resolve_events(raw)
    local t = type(raw)
    if t == "table" then return itertools.toset(raw) end
    if t == "string" then return { [raw] = true } end
    error("value error")
  end

  ---@param old string @`,` separated
  ---@param adds {[string]: true}
  ---@return string
  local function resolve_new_setopt(old, adds)
    local union = adds
    if old ~= "" then
      local olds = itertools.toset(strlib.iter_splits(old, ","))
      union = dictlib.merged(olds, adds)
    end
    return itertools.join(dictlib.iter_keys(union), ",")
  end

  ---@param event 'all'|string|string[]
  ---@param logic fun()
  function M.noautocmd(event, logic)
    local events = resolve_events(event)

    local old = vim.go.eventignore
    vim.go.eventignore = resolve_new_setopt(old, events)
    local ok, err = xpcall(logic, debug.traceback)
    vim.go.eventignore = old
    if not ok then error(err) end
  end
end

do
  --facts:
  --* two kind of keymaps: global, buffer-local
  --* the buffer-local one always gets fired solely, even the global one exists
  --* mapcheck() tells nothing about if the map is buffer-local or global
  --* maparg() returns only one definition, .buffer=0|1
  --* maparg/mapset has no bufnr param, so nvim_buf_call should be used

  ---@class infra.ctx.bufsubmode.KeymapDump
  ---@field buffer 0|1
  ---@field mode string @injected in keymap_dump_locally

  ---NB: should be wrapped by nvim_buf_call if needed
  ---@param mode string
  ---@param lhs string
  ---@return infra.ctx.bufsubmode.KeymapDump?
  local function keymap_dump_locally(mode, lhs)
    local dump = vim.fn.maparg(lhs, mode, false, true)
    ---@cast dump infra.ctx.bufsubmode.KeymapDump

    --no buffer-local one nor global one
    if dump.buffer == nil then return nil end
    --the global one exists, but not the buffer-local one
    if dump.buffer == 0 then return nil end

    assert(dump.buffer == 1)
    dump.mode = mode
    return dump
  end

  ---NB: should be wrapped by nvim_buf_call if needed
  ---@param dump infra.ctx.bufsubmode.KeymapDump
  local function keymap_restore_locally(dump)
    assert(dump.mode ~= nil)
    assert(dump.buffer == 1)
    vim.fn.mapset(dump.mode, false, dump)
  end

  ---@param bufnr integer
  ---@param mode_lhs_pairs [string,string][] @[(mode, lhs)]
  ---@return fun() @deinit
  function M.bufsubmode(bufnr, mode_lhs_pairs)
    local defs = {} --need to be restored
    local undefs = {} --need to be unset

    M.buf(bufnr, function()
      for _, pair in ipairs(mode_lhs_pairs) do
        local dump = keymap_dump_locally(unpack(pair))
        if dump then
          table.insert(defs, dump)
        else
          table.insert(undefs, pair)
        end
      end
    end)

    return function()
      if #defs > 0 then --
        M.buf(bufnr, function()
          for _, dump in ipairs(defs) do
            keymap_restore_locally(dump)
          end
        end)
      end

      for _, pair in ipairs(undefs) do
        ni.buf_del_keymap(bufnr, unpack(pair))
      end
    end
  end
end

---@param bufnr integer
---@param logic fun():...
---@return ...
function M.buf(bufnr, logic)
  --concern: follow vim._ctx
  local rets
  ni.buf_call(bufnr, function() rets = { logic() } end)
  return unpack(rets)
end

---@param winid integer
---@param logic fun():...
---@return ...
function M.win(winid, logic)
  --concern: follow vim._ctx
  local rets
  ni.win_call(winid, function() rets = { logic() } end)
  return unpack(rets)
end

return M
