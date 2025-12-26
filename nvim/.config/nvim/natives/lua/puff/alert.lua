---design choices
---* learn from dunst
---* position: right top
---* show multiple alerts with stack form
---* urgency: low, normal, critical
---* timeout
---* consist of: summary, body, icon/category/subject/source
---* no animation: slide, fade ...

local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("puff.alert", "info")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")

local xmark_ns = ni.create_namespace("puff.alert.icons")

local urgency_hi = { low = "JellyDebug", normal = "JellyInfo", critical = "JellyError" }

local bufnr, winid

local dismiss_at --os.time(), unix timestamp, in seconds
local timer = iuv.new_timer()

---@param summary string
---@param body string[]
---@param icon? string
---@param urgency 'low'|'normal'|'critical'
---@param timeout integer @in second
return function(summary, body, icon, urgency, timeout)
  assert(timeout > 0 and timeout <= 5, "unreasonable timeout value")

  if not (bufnr and ni.buf_is_valid(bufnr)) then
    bufnr = Ephemeral({ name = "puff://alert" })
    local function rm_xmarks() ni.buf_clear_namespace(bufnr, xmark_ns, 0, -1) end
    ni.create_autocmd("bufwipeout", { buffer = bufnr, once = true, callback = rm_xmarks })
  end

  timer:stop()

  do --adjust dismiss_at
    local now = os.time()
    if dismiss_at == nil then
      dismiss_at = now + timeout
    else
      dismiss_at = math.min(now + 5, dismiss_at + timeout)
    end
    jelly.debug("dismiss_at: %s", dismiss_at)
  end

  do --summary line
    local high = buflines.high(bufnr)

    local lnum
    if high == 0 then
      buflines.replace(bufnr, 0, summary)
      lnum = 0
    else
      buflines.appends(bufnr, high, { "", summary })
      lnum = high + 2
    end

    if icon ~= nil then --
      ni.buf_set_extmark(bufnr, xmark_ns, lnum, 0, { virt_text = { { icon } }, virt_text_pos = "inline", right_gravity = false })
    end
    mi.buf_highlight_line(bufnr, xmark_ns, lnum, "JellySource")
  end

  do --body lines
    assert(#body > 0)
    local high = buflines.high(bufnr)
    local hi = urgency_hi[urgency]

    buflines.appends(bufnr, high, body)

    for i = 1, #body do
      mi.buf_highlight_line(bufnr, xmark_ns, high + i, hi)
    end
  end

  if not (winid and ni.win_is_valid(winid)) then
    winid = rifts.open.fragment(bufnr, false, {
      relative = "editor",
      border = "single",
      title = "flashes",
      title_pos = "center",
    }, {
      width = 25,
      height = buflines.count(bufnr),
      horizontal = "right",
      vertical = "top",
    })
    prefer.wo(winid, "wrap", false)
  else
    local line_count = buflines.count(bufnr)
    local height_max = math.floor(vim.go.lines * 0.5)
    ni.win_set_config(winid, { height = math.min(line_count, height_max) })
  end

  wincursor.follow(winid, "bol")

  do
    local dismiss = vim.schedule_wrap(function()
      if not ni.win_is_valid(winid) then goto reset end
      --if the window get focused, wait for next round
      if ni.get_current_win() == winid then return end
      --still has time
      if os.time() < dismiss_at then return end

      --now we need to close the win
      ni.win_close(winid, false)

      ::reset::
      timer:stop()
      dismiss_at = nil
    end)

    --try to dismiss at every 1s
    timer:start(1000, 1000, dismiss)
  end
end
