--design choices
--* state: variables
--* overwrite builtin vim.{fn,api}
--* interpreters: vimscript, lua, shell
--* no ui_attach(cmdline|messages)
--* return-code: boolean
--* no distiguishing between stdout and stderr
--
--todo: support colored prompt? "\x1b[31m>\x1b[39m "?
--todo: :clear
--todo: history
--todo: maintain proper curwin, curbuf
--todo: completion for excmds and lua, could use fn.getcompletion()
--todo: hide sh window when there is new window created
--
--this prompt buffer does not fit my need i started to discover that.
--* prompt make <c-x><c-v> works not
--* fn.getcompletion()
--* prompt is visible to nvim_buf_get_lines
--* prompt_setcallback becomes a shakle
--* no history support

local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local Interpreter = require("sh.Interpreter")

local interpreter
do
  local impl = Interpreter()

  ---@type thread
  function interpreter()
    if coroutine.status(impl) == "dead" then impl = Interpreter() end
    return impl
  end
end

local create_buf
do
  ---@param bufnr integer
  ---@param lines string[]
  local function append_lines(bufnr, lines)
    if #lines == 0 then return end
    buflines.replaces(bufnr, -2, -1, lines)
  end

  local change_prompt
  do
    local last
    ---@param ok boolean
    function change_prompt(bufnr, ok)
      -- local this = ok and "> " or "!> "
      local this = ":" -- to enable <c-x><c-v>
      if last == this then return end
      vim.fn.prompt_setprompt(bufnr, this)
      last = this
    end
  end

  function create_buf()
    local bufnr = Ephemeral({ buftype = "prompt", bufhidden = "hide", handyclose = true, name = "sh://" })

    do
      local bm = bufmap.wraps(bufnr)
      --make <c-w> normal
      bm.i("<c-w>", "<s-c-w>")
      --completion
      prefer.bo(bufnr, "omnifunc", "v:lua.vim.lua_omnifunc")
      bm.i("<c-n>", "<c-x><c-o>")
      bm.i(".", [[.<c-x><c-o>]])
      bm.i("<c-d>", "<cmd>quit<cr>")
      bm.i("<tab>", "<c-x><c-v>")
      bm.i("<s-tab>", function()
        local keys = vim.fn.pumvisible() == 1 and "<c-p>" or "<c-x><c-v>"
        feedkeys(keys, "n")
      end)
    end

    local function stay_clean() prefer.bo(bufnr, "modified", false) end

    local aug = augroups.BufAugroup(bufnr, "sh", true)
    aug:repeats("BufHidden", { buffer = bufnr, callback = stay_clean })

    vim.fn.prompt_setcallback(bufnr, function(line)
      --just <cr>
      if line == "" then return stay_clean() end

      assert(coroutine.resume(interpreter()))
      local _, ok, results = assert(coroutine.resume(interpreter(), line))
      append_lines(bufnr, results)
      change_prompt(bufnr, ok)
      vim.schedule(stay_clean)
    end)

    change_prompt(bufnr, true)
    stay_clean()

    return bufnr
  end
end

---@param bufnr integer
local function open_win(bufnr)
  local winid = rifts.open.fragment( --
    bufnr,
    true,
    { relative = "editor", border = "single" },
    { width = 0.8, height = 0.3, vertical = "bot" }
  )

  local wo = prefer.win(winid)
  wo.wrap = true
  wo.list = false
  wo.number = false
  wo.relativenumber = false

  return winid
end

local bufnr, winid = -1, -1

return function()
  if not ni.buf_is_valid(bufnr) then bufnr = create_buf() end
  if not ni.win_is_valid(winid) then winid = open_win(bufnr) end

  ni.set_current_win(winid)
  ex("startinsert")
end
