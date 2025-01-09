local M = {}

local ropes = require("string.buffer")

local ascii = require("infra.ascii")
local ctx = require("infra.ctx")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("ido", "info")
local ni = require("infra.ni")
local VimRegex = require("infra.VimRegex")
local vsel = require("infra.vsel")
local wincursor = require("infra.wincursor")

local anchors = require("ido.anchors")
local collect_routes = require("ido.collect_routes")
local puff = require("puff")

local ts = vim.treesitter

local resolve_as_literals
do
  local rope = ropes.new(64)

  ---transform:
  ---* very magic
  ---* to fixed string
  ---* add word boundaries
  ---@param keyword string
  function resolve_as_literals(keyword)
    keyword = VimRegex.verymagic_escape(keyword)
    if ascii.is_letter(string.sub(keyword, 1, 1)) then rope:put("<") end
    rope:put(keyword)
    if ascii.is_letter(string.sub(keyword, -1, -1)) then rope:put(">") end
    return rope:get()
  end
end

---@alias ido.Session ido.ElasticSession|ido.CoredSession

local sessions = {}
do
  ---{bufnr:Session}
  ---@type {[integer]: ido.Session}
  sessions.kv = {}

  ---@param bufnr integer
  ---@return ido.Session?
  function sessions:session(bufnr)
    local ses = self.kv[bufnr]
    if ses == nil then return end
    assert(ses.status ~= "created")
    if ses.status == "active" then return ses end
    self.kv[bufnr] = nil
  end

  ---@param bufnr integer
  ---@return boolean
  function sessions:is_active(bufnr)
    local ses = self.kv[bufnr]
    if ses == nil then return false end
    assert(ses.status ~= "created")
    if ses.status == "active" then return true end
    self.kv[bufnr] = nil
    return false
  end

  ---@param bufnr integer
  ---@param ses ido.Session
  function sessions:activate(bufnr, ses)
    assert(bufnr == ses.bufnr)
    assert(self.kv[bufnr] == nil, "this buf has already activated a session")
    self.kv[bufnr] = ses
    ses:activate()
  end

  function sessions:deactivate(bufnr)
    local ses = self.kv[bufnr]
    if ses == nil then return end
    self.kv[bufnr] = nil
    ses:deactivate()
  end
end

do
  ---CAUTION: it uses the current window internally
  ---@param expr string
  ---@return integer start_lnum @0-based
  ---@return integer stop_lnum @0-based, exclusive
  local function eval_range_expr(winid, expr)
    return ctx.win(winid, function()
      local parsed = ni.parse_cmd(expr .. "w", {})
      local start_lnum, stop_lnum = unpack(assert(parsed.range))
      start_lnum = start_lnum - 1
      if stop_lnum == nil then stop_lnum = start_lnum + 1 end

      return start_lnum, stop_lnum
    end)
  end

  ---@param node TSNode
  local function resolve_node_range(node)
    local start_lnum, _, stop_lnum = node:range()

    --in lua, it seems that
    --* the root node ends (last_lnum+1, 0), in which lnum and col are exclusive
    --* the child node ends (last_lnum, col), in which lnum is inclusive, col is exclusive
    if node:parent() ~= nil then --
      stop_lnum = stop_lnum + 1
    end

    return start_lnum, stop_lnum
  end

  ---@param winid integer
  ---@param Session ido.Session
  local function main(winid, Session)
    local bufnr = ni.win_get_buf(winid)
    local cursor = wincursor.last_position(winid)

    sessions:deactivate(bufnr)

    local keyword = vsel.oneline_text(bufnr)
    if keyword == nil then return jelly.info("no selecting keyword") end

    local default_pattern = resolve_as_literals(keyword)
    puff.input({ icon = "", prompt = "ido", startinsert = false, default = default_pattern }, function(pattern)
      if pattern == nil or pattern == "" then return end

      if pcall(ts.get_parser, bufnr) then
        local nodes, paths = collect_routes(bufnr, cursor)
        puff.select(paths, { prompt = "ido regions" }, function(_, index)
          if index == nil then return end
          local start_lnum, stop_lnum = resolve_node_range(nodes[index])
          jelly.debug("node lines: (%s, %s)", start_lnum, stop_lnum)
          local ses = Session(winid, cursor, start_lnum, stop_lnum, pattern)
          if ses == nil then return end
          sessions:activate(bufnr, ses)
        end)
      else
        puff.select({ ".", ".,$", "1,.", "1,$" }, { prompt = "ido ranges" }, function(expr)
          if expr == nil then return end
          local start_lnum, stop_lnum = eval_range_expr(winid, expr)
          jelly.debug("expr lines: (%s, %s)", start_lnum, stop_lnum)
          local ses = Session(winid, cursor, start_lnum, stop_lnum, pattern)
          if ses == nil then return end
          sessions:activate(bufnr, ses)
          jelly.info("activated 'CoredSession', the core of each matches are not supposed to be modified")
        end)
      end
    end)
  end

  local flavor_to_session = {
    cored = "ido.CoredSession",
    elastic = "ido.ElasticSession",
  }

  ---@param flavor? 'cored'|'elastic' @nil=elastic
  function M.activate(flavor)
    flavor = flavor or "elastic"

    local winid = ni.get_current_win()
    local Session = require(flavor_to_session[flavor])

    main(winid, Session)
  end
end

do --M.deactivate
  local function select_one_to_deactivate()
    local entries = {}
    local bufs = {}
    for bufnr, ses in pairs(sessions.kv) do
      table.insert(entries, ses.title)
      table.insert(bufs, bufnr)
    end
    if #entries == 0 then return jelly.info("no active sessions") end

    puff.select(entries, { prompt = "ido deactivate" }, function(_, row)
      local nr = assert(bufs[row])
      sessions:deactivate(nr)
    end)
  end

  ---@param winid? integer
  function M.deactivate(winid)
    winid = winid or ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    if sessions:is_active(bufnr) then return sessions:deactivate(bufnr) end

    select_one_to_deactivate()
  end
end

function M.goto_truth(winid)
  winid = winid or ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local ses = sessions:session(bufnr)
  if ses == nil then return jelly.info("no active session") end

  local pos = anchors.pos(bufnr, ses.truth_xmid)
  if pos == nil then return jelly.debug("invald truth xmark") end
  wincursor.go(winid, pos.stop_lnum, pos.stop_col)
  ex("startinsert")
end

return M
