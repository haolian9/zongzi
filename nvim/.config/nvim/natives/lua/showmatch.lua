local M = {}

local augroups = require("infra.augroups")
local its = require("infra.its")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local setlib = require("infra.setlib")
local strlib = require("infra.strlib")
local unsafe = require("infra.unsafe")

local uv = vim.uv

local facts = {}
do
  facts.xmark_ns = ni.create_namespace("showmatch://xmark")

  --in ms
  --concern: autocmd OptionSet &matchtime
  facts.remain_time = 500

  facts.ignore_buftypes = setlib.new("terminal", "help", "quickfix")

  --concern: autocmd OptionSet &matchpairs
  facts.rights = its(strlib.iter_splits(vim.go.matchpairs, ",")) --
    :map(function(pair) return pair:sub(3, 3) end)
    :toset()
end

local marker = {}
do
  marker.xmid = nil
  marker.bufnr = nil

  function marker:clear()
    if self.xmid == nil then return end
    local bufnr, xmid = self.bufnr, self.xmid
    self.bufnr, self.xmid = nil, nil
    if not ni.buf_is_valid(bufnr) then return end
    ni.buf_del_extmark(bufnr, facts.xmark_ns, xmid)
  end

  ---@param bufnr integer
  ---@param lnum integer @0-based
  ---@param col integer @0-based
  function marker:set(bufnr, lnum, col)
    self:clear()
    local xmid = ni.buf_set_extmark(bufnr, facts.xmark_ns, lnum, col, { end_row = lnum, end_col = col + 1, hl_group = "MatchParen" })
    self.bufnr, self.xmid = bufnr, xmid
  end
end

local aug, bug ---@type infra.Augroup?, infra.BufAugroup?
local timer = uv.new_timer()
local clear_match = vim.schedule_wrap(function() marker:clear() end)

function M.activate()
  assert(not vim.go.showmatch, "conflict with &showmatch")
  if aug ~= nil then return end

  aug = augroups.Augroup("showmatch://")

  ---impl
  ---a) repeats:insertcharpre
  ---b) repeats:winenter -> once:insertenter -> repeats:insertcharPre
  ---as insertcharpre can be fired frequently, b can be efficient than a
  aug:repeats({ "BufWinEnter", "WinEnter" }, {
    callback = function(args)
      local bufnr = assert(args.buf)
      --todo: `:term` hasnt been taken down
      if facts.ignore_buftypes[prefer.bo(bufnr, "buftype")] then return end

      if bug then
        if bug.bufnr == bufnr then return end
        bug:unlink()
      end
      bug = augroups.BufAugroup(bufnr, "showmatch", false)

      ni.x.ns_set(facts.xmark_ns, { wins = { ni.get_current_win() } })

      bug:once("InsertEnter", {
        callback = function() --
          local function post_insertchar()
            local lnum, col = unsafe.findmatch()
            if not (lnum and col) then return end
            timer:stop()
            marker:set(bufnr, lnum, col)
            timer:start(facts.remain_time, 0, clear_match)
          end
          bug:repeats("InsertCharPre", {
            callback = function()
              if not facts.rights[vim.v.char] then return end
              vim.schedule(post_insertchar)
            end,
          })
        end,
      })
    end,
  })

  --necessary for VimEnter, re-activate
  aug:emit("WinEnter", { buffer = ni.get_current_buf() })
end

function M.deactivate()
  if aug ~= nil then
    aug:unlink()
    aug = nil
  end

  if bug ~= nil then
    bug:unlink()
    bug = nil
  end

  timer:stop()
  marker:clear()
end

return M
