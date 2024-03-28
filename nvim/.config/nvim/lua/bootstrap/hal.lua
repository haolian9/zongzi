local cmds = require("infra.cmds")
local dictlib = require("infra.dictlib")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("bootstrap.hal", "info")
local m = require("infra.keymap.global")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local api = vim.api
local usercmd = cmds.create

local common_root_comp = cmds.FlagComp.variable("root", function()
  local project = require("infra.project")
  local roots = { vim.fn.expand("%:p:h") }
  table.insert(roots, project.git_root())
  table.insert(roots, project.working_root())
  return dictlib.keys(fn.toset(roots))
end)

do --olds
  local olds = require("olds")
  olds.setup("/run/user/1000/redis.sock")
  olds.init()

  local spell = cmds.Spell("Olds", function(args)
    if args.subcmd == "files" then
      olds.oldfiles()
    elseif args.subcmd == "prune" then
      olds.prune()
    else
      jelly.warn("no such subcmd for :Olds")
    end
  end)
  spell:add_arg("subcmd", "string", false, "files", cmds.ArgComp.constant({ "files", "prune" }))
  cmds.cast(spell)
end

do --status&tabline
  prefer.def.statusline = [[%!v:lua.require'statusline'.render()]]
  prefer.def.tabline = [[%!v:lua.require'tabline'.render()]]

  usercmd("RenameTab", function(args)
    if #args.fargs == 0 then
      require("tabline").rename()
    else
      require("tabline").rename(args.args)
    end
  end, { nargs = "?" })
end

do --sting
  m.n("<leader>q", function() require("sting").toggle.qfwin() end)
  m.n("<leader>l", function() require("sting").toggle.locwin() end)

  do
    local subcmds = {
      ["switch-qflist"] = function() require("sting").quickfix.switch() end,
      ["switch-loclist"] = function() require("sting").location.switch() end,
      ["clear-qflist"] = function() require("sting").quickfix.clear() end,
      ["clear-loclist"] = function() require("sting").location.clear() end,
    }
    local spell = cmds.Spell("Sting", function(args) assert(subcmds[args.subcmd], "no such subcmd for :Sting")() end)
    spell:add_arg("subcmd", "string", true, nil, cmds.ArgComp.constant(dictlib.keys(subcmds)))
    cmds.cast(spell)
  end
end

do --coreutils
  usercmd("Edit", function(args)
    local fs = require("infra.fs")
    local bufpath = require("infra.bufpath")

    local fpath
    do
      local fname = args.args
      local basedir = bufpath.dir(api.nvim_get_current_buf())
      fpath = fs.joinpath(basedir, fname)
    end

    api.nvim_cmd({ cmd = "vsplit", args = { fpath }, mods = { split = "rightbelow" } }, { output = false })
  end, { nargs = 1 })

  do --:Mv
    local comp = cmds.ArgComp.variable(function()
      local in_cmdwin = vim.fn.getcmdwintype() ~= ""
      if in_cmdwin then return { vim.fn.expand("#:t") } end
      return { vim.fn.expand("%:t") }
    end)

    local spell = cmds.Spell("Mv", function(args) require("infra.coreutils").rename_filebuf(0, args.newname) end)
    spell:add_arg("newname", "string", true, nil, comp)
    cmds.cast(spell)
  end

  usercmd("Rm", function() require("infra.coreutils").rm_filebuf(0) end)

  usercmd("Mkdir", function(args)
    local bufpath = require("infra.bufpath")
    local coreutils = require("infra.coreutils")
    local fs = require("infra.fs")

    local dir
    do
      local name = args.args
      local basedir = bufpath.dir(api.nvim_get_current_buf())
      dir = fs.joinpath(basedir, name)
    end

    assert(coreutils.mkdir(dir))
  end, { nargs = 1 })
end

do --visualapps
  m.x("*", [[:lua require"visualapps".search_forward()<cr>]])
  m.x("#", [[:lua require"visualapps".search_backward()<cr>]])

  m.x("<leader>s", [[:lua require"visualapps".substitute()<cr>]])
  m.x("<leader>g", [[:lua require"visualapps".vimgrep()<cr>]])
end

do --grep
  m.n("<leader>/", function() require("grep").input() end)
  m.x("<leader>/", [[:lua require("grep").vsel()<cr>]])

  usercmd("Todo", function() require("grep").text([[\btodo@?]]) end)

  do --:Rg
    local function root_default()
      local project = require("infra.project")
      return project.git_root() or project.working_root()
    end
    local sort_comp = cmds.FlagComp.constant("sort", { "none", "path", "modified", "accessed", "created" })
    -- see: rg --type-list
    local type_comp = cmds.FlagComp.constant("type", { "c", "go", "h", "lua", "py", "sh", "systemd", "vim", "zig" })
    local function is_extra_flag(flag) return flag ~= "root" and flag ~= "pattern" end

    local spell = cmds.Spell("Rg", function(args)
      local extra = {}
      local iter = fn.filtern(is_extra_flag, fn.items(args))
      for key, val in iter do
        if val == true then table.insert(extra, string.format("--%s", key)) end
        table.insert(extra, string.format("--%s=%s", key, val))
      end

      require("grep").rg(args.root, args.pattern, extra)
    end)

    -- stylua: ignore
    do
      spell:add_flag("root",          "string", false, root_default, common_root_comp)
      spell:add_flag("fixed-strings", "true",   false)
      spell:add_flag("hidden",        "true",   false)
      spell:add_flag("max-depth",     "number", false)
      spell:add_flag("multiline",     "true",   false)
      spell:add_flag("no-ignore",     "true",   false)
      spell:add_flag("sort",          "string", false, nil,          sort_comp)
      spell:add_flag("sortr",         "string", false, nil,          sort_comp)
      spell:add_flag("type",          "string", false, nil,          type_comp)
    end

    spell:add_arg("pattern", "string", true)
    cmds.cast(spell)
  end
end

do --winjump&swap
  for i = 1, 9 do
    m.n("<leader>" .. i, function() require("winjump").to(i) end)
  end
  m.n("<leader>0", function() require("winjump").display_panes() end)

  m.n("<c-w>x", function() require("winswap")() end)
end

do --kite
  m.n("-", function() require("kite").fly() end)
  m.n("_", function() require("kite").land() end)
  m.n("[k", function() require("kite").rhs_open_sibling_file("prev") end)
  m.n("]k", function() require("kite").rhs_open_sibling_file("next") end)
end

do --fond
  m.n("<leader>s", function() require("fond").files() end)
  m.n("<leader>g", function() require("fond").tracked() end)
  m.n("<leader>b", function() require("fond").buffers() end)
  m.n("<leader>u", function() require("fond").statuses() end)
  m.n("<leader>m", function() require("fond").olds() end)
  m.n("<leader>f", function() require("fond").siblings() end)
  m.n("<leader>d", function() require("fond").document_symbols() end)
  m.n("<leader>w", function() require("fond").workspace_symbols() end)
  m.n("<leader>p", function() require("fond").windows() end) ---p -> pane
  m.n("<leader>t", function() require("fond").ctags() end)
  -- with no cache
  m.n("<leader>S", function() require("fond").files(false) end)
  m.n("<leader>G", function() require("fond").tracked(false) end)
  m.n("<leader>M", function() require("fond").olds(false) end)
  m.n("<leader>F", function() require("fond").siblings(false) end)
  m.n("<leader>D", function() require("fond").document_symbols(false) end)
  m.n("<leader>W", function() require("fond").workspace_symbols(false) end)
  m.n("<leader>T", function() require("fond").ctags(false) end)
end

do --parrot
  m.i("<tab>", function()
    local parrot = require("parrot")
    local nvimkeys = require("infra.nvimkeys")

    if parrot.running() then
      if parrot.goto_next() then
        -- dirty hack for: https://github.com/neovim/neovim/issues/23549
        api.nvim_feedkeys(nvimkeys("<esc>l"), "n", false)
      else
        ex("startinsert")
      end
      return
    end

    local pumvisible = vim.fn.pumvisible() == 1

    if not pumvisible then
      if parrot.expand(true) then return end
    end

    do --pum?<c-y>:<tab>
      assert(strlib.startswith(api.nvim_get_mode().mode, "i"))
      local key = pumvisible and "<c-y>" or "<tab>"
      api.nvim_feedkeys(nvimkeys(key), "n", false)
    end
  end)
  m({ "n", "x", "s" }, "<tab>", function()
    local parrot = require("parrot")
    local nvimkeys = require("infra.nvimkeys")

    if parrot.goto_next() then return end
    -- for tmux only which can not distinguish between <c-i> and <tab>
    api.nvim_feedkeys(nvimkeys("<tab>"), "n", false)
  end)
  m.x("<s-c>", [[:lua require("parrot").purify_placeholder()<cr>]])

  usercmd("ParrotCancel", function() require("parrot").cancel() end)

  do --:ParrotEdit
    local comp = cmds.ArgComp.constant(function() return require("parrot").comp.editable_chirps() end)
    local function default() return prefer.bo(api.nvim_get_current_buf(), "filetype") end

    local spell = cmds.Spell("ParrotEdit", function(args) require("parrot").edit_chirps(args.filetype) end)
    spell:add_arg("filetype", "string", false, default, comp)
    cmds.cast(spell)
  end
end

-- stylua: ignore
do --gallop
  local last_chars
  m({ "n", "x" }, "s",   function() last_chars = require("gallop").words(2, last_chars) or last_chars end)
  m({ "n", "x" }, [[\]], function() last_chars = require("gallop").strings(2, last_chars) or last_chars end)
  m({ "n", "x" }, "gl",  function() require("gallop").lines() end)
  m({ "n", "x" }, "go",  function() require("gallop").cursorcolumn() end)

  --the rhs must be a vimscript(?) expr for an operater-pending mapping
  --inspired by echasnovski's mini.jump2d
  m.o("s", "<cmd>lua require'gallop'.strings(2)<cr>")
end

do --comet
  m.n("gc", function() require("comet").comment_curline() end)
  m.n("gC", function() require("comet").uncomment_curline() end)
  m.x("gc", [[:lua require("comet").comment_vselines()<cr>]])
  m.x("gC", [[:lua require("comet").uncomment_vselines()<cr>]])
end

do --digits
  m.n("<leader>x", function() require("digits.status").floatwin() end)

  do --:Git
    local handlers = {
      status = function() require("digits.status").floatwin() end,
      push = function() require("digits.push")() end,
      hunks = function() require("digits.diffhunks").setloclist() end,
      diff = function() require("digits.diff")() end,
      diff_file = function() require("digits.diff")(nil, api.nvim_get_current_buf()) end,
      diff_cached = function() require("digits.diff")(nil, nil, true) end,
      log = function() require("digits.log")(nil, 100) end,
      commit = function() require("digits.commit").tab() end,
    }
    local comp = cmds.ArgComp.constant(dictlib.keys(handlers))
    local spell = cmds.Spell("Git", function(args) assert(handlers[args.subcmd])() end)
    spell:add_arg("subcmd", "string", false, "status", comp)
    cmds.cast(spell)
  end
end

-- stylua: ignore
do --misc keymaps
  m.n("<c-w>z",    function() require("winzoom")() end)
  m.n("<leader>.", function() require("reveal")(nil, true) end)
  m.n("g:",        function() require("sh")() end)
  m.n("<leader>`", function() require("floatshell")() end)

  m({ "x", "o" }, "ii", function() require("indentobject")() end)
end

do --misc cmds
  usercmd("Resize", function() require("winresize")() end)
  usercmd("Pstree", function(args) require("pstree").run(args.fargs) end, { nargs = "*" })
  usercmd("Punctuate", function() require("punctconv").multiline_vsel() end, { nargs = 0, range = true })
  usercmd("W", function() require("sudowrite")() end)
  usercmd("ThisLineOnGithub", function()
    local uri = require("thislineongithub")()
    if uri == nil then return end
    vim.fn.setreg("+", uri)
    jelly.info("copied: %s", uri)
  end)
  usercmd("CopyFilePath", function()
    local bufpath = require("infra.bufpath")
    local fpath = bufpath.file(api.nvim_get_current_buf())
    if fpath == nil then return jelly.warn("no file associated to this buffer") end
    vim.fn.setreg("+", fpath)
    jelly.info("copied: %s", fpath)
  end)
  usercmd("TailSubprocLog", function() require("infra.subprocess").tail_logs() end)

  _G.inspect = function(...) require("inspect")(...) end
end

do --:Term
  local spell = cmds.Spell("Term", function(args) require("floatshell")(args.root) end)
  spell:add_arg("root", "string", false, nil, common_root_comp)
  cmds.cast(spell)
end

do --:Nag
  local function action(args)
    local open = args.open
    local nag = require("nag")
    if open == "tab" then return nag.tab() end
    nag.split(open)
  end
  local comp = cmds.ArgComp.constant({ "tab", "left", "right", "above", "below" })

  local spell = cmds.Spell("Nag", action)
  spell:enable("range")
  spell:add_arg("open", "string", false, "tab", comp)
  cmds.cast(spell)
end

do --:Morph
  local comp = cmds.ArgComp.variable(function()
    local bufnr = api.nvim_get_current_buf()
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "" then return {} end
    return require("morphling").comp.available_profiles(ft)
  end)

  local spell = cmds.Spell("Morph", function(args) require("morphling").morph(nil, nil, args.profile) end)
  spell:add_arg("profile", "string", false, "default", comp)
  cmds.cast(spell)
end

do --buds
  local spell = cmds.Spell("Buds", function(args)
    local buds = require("buds")
    local bufnr = api.nvim_get_current_buf()
    if args.op == "attach" then
      buds.attach(bufnr)
    elseif args.op == "detach" then
      buds.detach(bufnr)
    else
      error("unreachable")
    end
  end)
  spell:add_arg("op", "string", true, nil, cmds.ArgComp.constant({ "attach", "detach" }))
  cmds.cast(spell)
end
