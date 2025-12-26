local augroups = require("infra.augroups")
local Ephemeral = require("infra.Ephemeral")
local feedkeys = require("infra.feedkeys")
local mi = require("infra.mi")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")
local log = require("infra.logging").newlogger("optilsp.open_floatwin", "info")

local ni = require("infra.ni")

---@param winid integer
---@return boolean
local function is_valid_win(winid) return winid ~= -1 and ni.win_is_valid(winid) end

--- @class optilsp.open_floatwin.Opts
--- @field height? integer
--- @field width? integer
--- @field close_events? string[]|false @false=no-auto-close
--- @field focus_id? string
--- @field focus? boolean @nil=true, when focus_id matches

---@param opts optilsp.open_floatwin.Opts
---@return any
local function normalize_opts(opts)
  opts = opts or {}
  if opts.focus == nil then opts.focus = true end
  if opts.close_events == nil then opts.close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre" } end
  if opts.close_events == false then opts.close_events = {} end
  return opts
end

local bufnr, winid, focus_id = -1, -1, nil

---customize:
---* no syntax/style/highlights
---* &wrap, &nofoldenable
---* no auto-close when win landed
---* default close_events
---
---@param contents string[]
---@param opts optilsp.open_floatwin.Opts
---@return integer bufnr
---@return integer winid
return function(contents, syntax, opts)
  local _ = syntax
  opts = normalize_opts(opts)
  log.debug("opts: %s", opts)

  local source_winid = ni.get_current_win()
  local source_bufnr = ni.win_get_buf(source_winid)

  --set the landwin free
  if is_valid_win(winid) and mi.win_is_landed(winid) then
    bufnr, winid, focus_id = -1, -1, nil
  end

  --focus the previous preview window
  if opts.focus and opts.focus_id == focus_id then
    if is_valid_win(winid) then
      ni.set_current_win(winid)
      --for i_c-k signature
      if strlib.startswith(ni.get_mode().mode, "i") then feedkeys("<esc>", "n") end
      return winid, bufnr
    end
  end

  --close the previous preview window
  if is_valid_win(winid) then
    ni.win_close(winid, false)
    assert(not (bufnr and ni.buf_is_valid(bufnr)))
    winid, bufnr, focus_id = -1, -1, nil
  end

  focus_id = opts.focus_id

  bufnr = Ephemeral({ namepat = "optilsp://{bufnr}", handyclose = true }, contents)

  do --open win
    local max_width = ni.win_get_width(source_winid)
    local width, height = 0, 0
    for _, line in ipairs(contents) do
      local w = ni.strwidth(line)
      if w > width then width = w end
      if w == 0 then
        height = height + 1
      else
        height = height + math.ceil(w / max_width)
      end
    end
    width = math.min(width, max_width)
    log.debug("width=%d, height=%d", width, height)

    winid = rifts.open.win(bufnr, false, { relative = "cursor", row = 1, col = 0, width = width, height = height })

    local wo = prefer.win(winid)
    wo.foldenable = false
    wo.wrap = true
    wo.winfixheight = true --keep height when split below
    wo.winfixwidth = true --keep width when split right
    wo.winfixbuf = true
  end

  if #opts.close_events > 0 then --auto-close
    local aug = augroups.BufAugroup(bufnr, "optilsp.floatwin", true)
    ni.create_autocmd(opts.close_events, {
      group = aug.group,
      buffer = source_bufnr,
      once = true,
      callback = function()
        if not (winid and ni.win_is_valid(winid)) then return end
        if mi.win_is_landed(winid) then return end --dont close a landwin
        local old_winid = winid
        winid, bufnr, focus_id = -1, -1, nil
        vim.schedule(function() --schedule to avoid E565
          ni.win_close(old_winid, false)
        end)
      end,
    })
  end

  return bufnr, winid
end
