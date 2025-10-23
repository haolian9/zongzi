local cmds = require("infra.cmds")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local G = require("infra.G")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("bootstrap.hal", "info")
local m = require("infra.keymap.global")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")

local common_root_comp = cmds.FlagComp.variable("root", function()
  local roots = { vim.fn.expand("%:p:h") }
  table.insert(roots, project.git_root())
  table.insert(roots, project.working_root())
  return dictlib.keys(itertools.toset(roots))
end)

local common_bufname_comp = cmds.ArgComp.variable(function()
  local name = vim.fn.expand("%:t")
  if name == "" then return {} end
  if strlib.contains(name, "://") then return {} end
  return { name }
end)

do --status&tabline
  prefer.def.statusline = [[%!v:lua.require'statusline'.render()]]
  prefer.def.tabline = [[%!v:lua.require'tabline'.render()]]

  cmds.create("RenameTab", function(args)
    if #args.fargs == 0 then
      require("tabline").rename()
    else
      require("tabline").rename(args.args)
    end
  end, { nargs = "?" })
end

do --re-define builtin keymap
  m.n(",", function() require("infra.repeats").rhs_comma() end)
  m.n(";", function() require("infra.repeats").rhs_semicolon() end)
  m.n("(", function() require("infra.repeats").rhs_parenleft() end)
  m.n(")", function() require("infra.repeats").rhs_parenright() end)
  m.n(".", function() require("infra.repeats").rhs_dot(ni.get_current_buf()) end)

  m.i("<c-o>", function() require("ico")() end)
  m.i("<c-x><c-f>", function() require("icxcf")() end)
end

do --pairs
  ---@param prev string
  ---@param next string
  local function RHS(prev, next)
    local function safe_ex(cmd)
      local ok, err = pcall(ex.cmd, cmd)
      if ok then return end
      assert(err ~= nil)
      --err: "{file}:{line} Vim:Exxx {error}"
      local err_at = select(1, strlib.find(err, "Vim:E"))
      assert(err_at)
      jelly.info("%s", string.sub(err, err_at))
    end

    local function prev_fn() safe_ex(prev) end
    local function next_fn() safe_ex(next) end

    return function(prev_or_next)
      local cmd = prev_or_next and prev or next
      return function()
        require("infra.repeats").remember_paren(next_fn, prev_fn)
        safe_ex(cmd)
      end
    end
  end

  local rhs_c = RHS("cprev", "cnext")
  local rhs_l = RHS("lprev", "lnext")
  local rhs_b = RHS("bprev", "bnext")
  local rhs_a = RHS("prev", "next")

  m.n("[c", rhs_c(true))
  m.n("]c", rhs_c(false))
  m.n("[l", rhs_l(true))
  m.n("]l", rhs_l(false))
  m.n("[b", rhs_b(true))
  m.n("]b", rhs_b(false))
  m.n("[a", rhs_a(true))
  m.n("]a", rhs_a(false))
end

do --sting
  m.n("<leader>c", function() require("sting").toggle.qfwin() end)
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
  do
    local function main(name)
      local fs = require("infra.fs")
      local bufpath = require("infra.bufpath")

      local basedir = bufpath.dir(ni.get_current_buf())
      local fpath = fs.joinpath(basedir, name)
      require("infra.bufopen").right(fpath)
    end

    local spell = cmds.Spell("Edit", function(args)
      if args.name ~= nil then return main(args.name) end

      require("puff").input({ icon = "📝", prompt = "edit", startinsert = "a" }, function(name)
        if name == nil or name == "" then return end
        main(name)
      end)
    end)
    spell:add_arg("name", "string", false)
    cmds.cast(spell)
  end

  do --:Mv
    local spell = cmds.Spell("Mv", function(args)
      local coreutils = require("infra.coreutils")
      local bufnr = ni.get_current_buf()

      if args.name ~= nil then return coreutils.rename_filebuf(bufnr, args.name) end

      local default = vim.fn.fnamemodify(ni.buf_get_name(bufnr), ":t")
      require("puff").input({ icon = "🆎", prompt = "mv", default = default }, function(name)
        if name == nil or name == "" then return end
        coreutils.rename_filebuf(bufnr, name)
      end)
    end)
    spell:add_arg("name", "string", false, nil, common_bufname_comp)
    cmds.cast(spell)
  end

  do --:Cp
    ---@param root string
    ---@param src_bufnr integer
    ---@param dest_name string
    local function main(root, src_bufnr, dest_name)
      local fs = require("infra.fs")
      local bufopen = require("infra.bufopen")

      bufopen("right", fs.joinpath(root, dest_name))
      if ni.get_current_buf() == src_bufnr then return jelly.debug("same buf") end
      ex.cmd("read", ni.buf_get_name(src_bufnr))
    end

    local spell = cmds.Spell("Cp", function(args)
      local bufpath = require("infra.bufpath")
      local puff = require("puff")

      local bufnr = ni.get_current_buf()

      local root = bufpath.dir(bufnr)
      if root == nil then return jelly.info("no dir related to buf#%s", bufnr) end

      if args.name ~= nil then return main(root, bufnr, args.name) end

      local default = vim.fn.fnamemodify(ni.buf_get_name(bufnr), ":t")
      puff.input({ icon = "🆎", prompt = "cp", default = default }, function(name)
        if name == nil or name == "" then return end
        main(root, bufnr, name)
      end)
    end)
    spell:add_arg("name", "string", false, nil, common_bufname_comp)
    cmds.cast(spell)
  end

  cmds.create("Rm", function() require("infra.coreutils").rm_filebuf(0) end)

  do
    local function main(name)
      local bufpath = require("infra.bufpath")
      local coreutils = require("infra.coreutils")
      local fs = require("infra.fs")

      local basedir = bufpath.dir(ni.get_current_buf())
      local dir = fs.joinpath(basedir, name)

      assert(coreutils.mkdir(dir))
    end

    local spell = cmds.Spell("Mkdir", function(args)
      if args.name ~= nil then return main(name) end

      require("puff").input({ icon = "📁", prompt = "mkdir", startinsert = "a" }, function(name)
        if name == nil or name == "" then return end
        main(name)
      end)
    end)
    spell:add_arg("name", "string", false)
    cmds.cast(spell)
  end
end

do --visualapps
  m.x("*", [[:lua require"visualapps".search_forward()<cr>]])
  m.x("#", [[:lua require"visualapps".search_backward()<cr>]])

  m.x([[\s]], [[:lua require"visualapps".substitute()<cr>]])
end

do --eureka
  m.n([[\\]], function() require("eureka").input() end)
  m.x([[\\]], [[:lua require("eureka").vsel()<cr>]])

  do --:Eureka
    local spell = cmds.Spell("Eureka", function(args)
      local eureka = require("eureka")
      if args.regex then
        eureka.text(args.regex)
      else
        eureka.input()
      end
    end)
    spell:add_arg("regex", "string", false)
    cmds.cast(spell)
  end

  cmds.create("Todo", function() require("eureka").text([[\btodo@?]]) end)

  do --:Rg
    local function root_default() return project.git_root() or project.working_root() end
    local sort_comp = cmds.FlagComp.constant("sort", { "none", "path", "modified", "accessed", "created" })
    -- see: rg --type-list
    local type_comp = cmds.FlagComp.constant("type", { "c", "go", "h", "lua", "py", "sh", "systemd", "vim", "zig" })
    local function is_extra_flag(flag) return flag ~= "root" and flag ~= "pattern" end

    local spell = cmds.Spell("Rg", function(args)
      local extra = {}
      ---@diagnostic disable-next-line: param-type-mismatch
      local iter = itertools.filtern(dictlib.items(args), is_extra_flag)
      for key, val in iter do
        if val == true then
          table.insert(extra, string.format("--%s", key))
        elseif val == false then
          --pass
        else
          table.insert(extra, string.format("--%s=%s", key, val))
        end
      end

      require("eureka").rg(args.root, args.pattern, extra)
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

do --bufgrep
  m.x([[\b]], [[:lua require"bufgrep".vsel()<cr>]])

  do --:BufGrep
    local spell = cmds.Spell("BufGrep", function(args)
      local bufgrep = require("bufgrep")
      if args.regex then
        bufgrep.text(args.regex)
      else
        bufgrep.input()
      end
    end)
    spell:add_arg("regex", "string", false)
    cmds.cast(spell)
  end
end

do --winjump&swap
  ---@type winjump.G
  local g = G("winjump")
  g.display_panes_font = vim.go.background == "light" and "electronic" or "ansi_shadow"

  for i = 1, 9 do
    m.n("<leader>" .. i, function() require("winjump").to(i) end)
  end
  m.n("<leader>0", function() require("winjump").display_panes() end)

  m.n("<c-w>x", function() require("winswap")() end)
end

do --kite
  local g = G("kite")
  g.max_entries_per_dir = 999

  m.n("-", function() require("kite").fly() end)
  m.n("_", function() require("kite").land() end)
  m.n("[k", function() require("kite").open_sibling_file("prev") end)
  m.n("]k", function() require("kite").open_sibling_file("next") end)
end

do --fond
  m.n("<leader>s", function() require("fond").files() end)
  m.n("<leader>g", function() require("fond").tracked() end)
  m.n("<leader>u", function() require("fond").statuses() end)
  m.n("<leader>m", function() require("fond").olds() end)
  m.n("<leader>f", function() require("fond").siblings() end)
  m.n("<leader>d", function() require("fond").document_symbols() end)
  m.n("<leader>t", function() require("fond").ctags() end)
  m.n("<leader>h", function() require("fond").helps() end)

  --no-cache version
  m.n("<leader>S", function() require("fond").files(false) end)
  m.n("<leader>G", function() require("fond").tracked(false) end)
  m.n("<leader>M", function() require("fond").olds(false) end)
  m.n("<leader>F", function() require("fond").siblings(false) end)
  m.n("<leader>D", function() require("fond").document_symbols(false) end)
  m.n("<leader>T", function() require("fond").ctags(false) end)
  m.n("<leader>H", function() require("fond").helps(false) end)

  do
    local spell = cmds.Spell("Fond", function(args) assert(require("fond")[args.provider])(args.fresh) end)
    spell:add_arg("provider", "string", true, nil, cmds.ArgComp.constant({ "windows" }))
    spell:add_flag("fresh", "true", false)
    cmds.cast(spell)
  end
end

do --beckon
  m.n("<leader>a", function() require("beckon").args() end)
  m.n("<leader>b", function() require("beckon").buffers() end)
  m.n("?", function() require("beckon.beckonize")(nil, nil, { remember = true }) end)
  m.n("<leader>;", function() require("beckon").cmds() end)

  cmds.create("Digraphs", function() require("beckon").digraphs() end)
  cmds.create("Emojis", function() require("beckon").emojis() end)
end

do --parrot
  m.x("<tab>", [[:lua require'parrot'.visual_expand()<cr>]])
  m.i("<s-tab>", function() require("parrot").visual_expand() end)
  m.i("<tab>", function() require("parrot").itab() end)

  m.i("<c-0>", function() require("parrot").jump(1) end)
  m.i("<c-9>", function() require("parrot").jump(-1) end)
  m.n("<c-0>", function() require("parrot").jump(1) end)
  m.n("<c-9>", function() require("parrot").jump(-1) end)
  m.x("<c-0>", [[:lua require("parrot").jump(1)<cr>]])
  m.x("<c-9>", [[:lua require("parrot").jump(-1)<cr>]])

  cmds.create("ParrotCancel", function() require("parrot").cancel() end)

  do --:ParrotEdit
    local comp = cmds.ArgComp.constant(function() return require("parrot").comp.editable_chirp_fts() end)
    local function default() return prefer.bo(ni.get_current_buf(), "filetype") end

    local spell = cmds.Spell("ParrotEdit", function(args) require("parrot").edit_chirp(args.filetype) end)
    spell:add_flag("open", "string", false, "right", cmds.FlagComp.constant("open", { "left", "right", "above", "below", "inplace", "tab" }))
    spell:add_arg("filetype", "string", false, default, comp)
    cmds.cast(spell)
  end
end

do --gallop
  do
    local last_chars
    m({ "n", "x" }, "s", function() last_chars = require("gallop").words(2, last_chars, true) or last_chars end)
  end

  do
    local last_chars
    m({ "n", "x" }, "S", function() last_chars = require("gallop").strings(9, last_chars, true) or last_chars end)
  end

  m({ "n", "x" }, "gl", function() require("gallop").lines() end)
  m({ "n", "x" }, "go", function() require("gallop").cursorcolumn() end)

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

do --:Git
  m.n("<leader>x", function() require("digits.cmds.status").floatwin() end)
  m.n("<leader>X", function() require("digits.cmds.status").win1000() end)

  cmds.create("GitStatus", function() require("digits.cmds.status").floatwin() end)
  cmds.create("GitPush", function() require("digits.cmds.push").floatwin() end)
  cmds.create("GitHunks", function() require("digits.cmds.diffhunks").setloclist() end)
  cmds.create("GitDiff", function() require("digits.cmds.diff")() end)
  cmds.create("GitDiffFile", function() require("digits.cmds.diff")(nil, ni.get_current_buf()) end)
  cmds.create("GitDiffCached", function() require("digits.cmds.diff")(nil, nil, true) end)
  cmds.create("GitCommit", function() require("digits.cmds.commit").tab() end)
  cmds.create("GitBlame", function() require("digits.cmds.blame").file() end)
  cmds.create("GitBlameLine", function() require("digits.cmds.blame").line() end)
  cmds.create("GitFixup", function() require("digits.cmds.fixup").floatwin() end)

  do --:GitLog
    local spell = cmds.Spell("GitLog", function(args) --
      require("digits.cmds.log")(nil, args.n, args.path)
    end)
    local comp = cmds.ArgComp.constant({ "%", "#" })
    spell:add_arg("path", "string", false, nil, comp)
    spell:add_flag("n", "number", false, 100)
    cmds.cast(spell)
  end
end

do --misc keymaps
  --stylua: ignore start
  m.n("<c-w>z",    function() require("winzoom")() end)
  m.n("<leader>.", function() require("reveal")(nil, true) end)
  m.n("g:",        function() require("sh")() end)
  m.n("<leader>`", function() require("floatshell")() end)
  --stylua: ignore end

  m.n("<space>j", function() require("blanklines").below() end)
  m.n("<space>J", function() require("blanklines").above() end)

  m({ "x", "o" }, "ii", function() require("indentobject")() end)
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

do --:Sculpt
  local comp = cmds.ArgComp.variable(function()
    local bufnr = ni.get_current_buf()
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "" then return {} end
    return require("sculptor").comp.available_profiles(ft)
  end)

  local spell = cmds.Spell("Sculpt", function(args) require("sculptor").sculpt(nil, nil, args.profile) end)
  spell:add_arg("profile", "string", false, "default", comp)
  cmds.cast(spell)
end

do --furrow
  cmds.create("Furrow", function() require("furrow.interactive")() end, { nargs = 0, range = true })
  m.x("<cr>", [[:lua require"furrow.interactive"()<cr>]])
end

do --ido
  m.x("gii", [[:lua require'ido'.activate('elastic')<cr>]])
  m.x("gio", [[:lua require'ido'.activate('cored')<cr>]])
  m.n("gi0", function() require("ido").goto_truth() end)

  do --:Ido
    local spell = cmds.Spell("Ido", function(args, ctx)
      local op = (function()
        if args.op ~= nil then return args.op end
        if ctx.range == 0 then return "deactivate" end
        return "activate"
      end)()
      assert(require("ido")[op])()
    end)
    spell:add_arg("op", "string", false, nil, cmds.ArgComp.constant({ "activate", "deactivate" }))
    spell:enable("range")
    cmds.cast(spell)
  end
end

do --:AnsiEsc
  local spell = cmds.Spell("AnsiEsc", function(args) require("ansiesc")(0, args.open_mode) end)
  spell:add_arg("open_mode", "string", false, "inplace", cmds.ArgComp.constant({ "inplace", "left", "right", "above", "below", "tab" }))
  cmds.cast(spell)
end

do --textswap
  m.x("X", [[:lua require'textswap'.swap()<cr>]])

  do --:Swap
    local spell = cmds.Spell("Swap", function(_, ctx)
      local textswap = require("textswap")
      if ctx.range ~= 0 then return textswap() end
      textswap.cancel()
    end)
    spell:enable("range")
    cmds.cast(spell)
  end
end

do --misc _G
  _G.inspect = function(...) require("inspect")(...) end
end

do --misc cmds
  cmds.create("Resize", function() require("winresize")() end)
  cmds.create("Pstree", function(args) require("pstree").run(args.fargs) end, { nargs = "*" })
  cmds.create("Punctuate", function() require("punctconv").multiline_vsel() end, { nargs = 0, range = true })
  cmds.create("W", function() require("sudowrite")() end)
  cmds.create("ThisLineOnGithub", function()
    local uri = require("thislineongithub")()
    if uri == nil then return end
    vim.fn.setreg("+", uri)
    jelly.info("copied: %s", uri)
  end)
  cmds.create("CopyFilePath", function()
    local bufpath = require("infra.bufpath")
    local fpath = bufpath.file(ni.get_current_buf())
    if fpath == nil then return jelly.warn("no file associated to this buffer") end
    vim.fn.setreg("+", fpath)
    jelly.info("copied: %s", fpath)
  end)
  cmds.create("TailSubprocLog", function() require("infra.subprocess").tail_logs() end)
end
