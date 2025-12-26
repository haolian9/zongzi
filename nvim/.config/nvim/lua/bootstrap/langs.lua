local augroups = require("infra.augroups")
local bufopen = require("infra.bufopen")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("hal", "info")
local jumplist = require("infra.jumplist")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local wincursor = require("infra.wincursor")

local profiles = require("profiles")

local ts = vim.treesitter
local lsp = vim.lsp

local function setlocal(...) ex("setlocal", ...) end

---supposed to execute in FileType autocmd context
---* based on `:h local-options`, It's possible to set a local window option specifically for a type of buffer.
---* and in the filetype autocmd context args.buf == ni.get_current_buf() always
local function fold_with_squirrel() --
  ex("setlocal", "foldmethod=expr", [[foldexpr=v:lua.require'squirrel.folding'.expr()]])
end

local general_lsp = {}
do
  function general_lsp.start(langser, bufnr)
    local spec = vim.deepcopy(assert(lsp.config[langser]))
    if vim.fn.executable(spec.cmd[1]) ~= 1 then --
      return jelly.warn("%s not found, no starting lsp", spec.cmd[1])
    end
    --unlike vim.lsp.enable() which invokes root_dir() as (bufnr,on_decide)
    if type(spec.root_dir) == "function" then spec.root_dir = spec.root_dir(bufnr) end
    ---@diagnostic disable-next-line: missing-fields
    vim.lsp.start(spec, { bufnr = bufnr })
  end

  function general_lsp.prefers(bufnr) --
    prefer.bo(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  end

  do
    local function rhs_accept_first()
      --if pum is started, <c-y>
      if vim.fn.pumvisible() == 1 then return feedkeys("<c-y>", "n") end

      do --otherwise, behave as <c-n><c-y>
        --necessary workaround
        local aug = augroups.Augroup("pum://accept_first")
        --todo: i believe this aucmd does not get triggered properly
        aug:once("CompleteChanged", { nested = true, callback = function() feedkeys("<c-y>", "n") end })
        feedkeys("<c-x><c-o>", "n")
      end
    end

    local function rhs_accept_current()
      local key = vim.fn.pumvisible() == 1 and "<c-y>" or "<cr>"
      return feedkeys(key, "n")
    end

    ---@param open_mode infra.bufopen.Mode
    local function make_onlist_fn(open_mode)
      ---@param args {title:string, items:vim.quickfix.entry[], context: {bufnr:integer,method:string}}
      return function(args)
        assert(#args.items > 0)

        local item0 = args.items[1]
        bufopen(open_mode, assert(item0.bufnr or item0.filename))
        local winid = ni.get_current_win()

        jumplist.push_here()

        if #args.items == 1 then --
          return wincursor.go(winid, item0.lnum - 1, item0.col - 1)
        end

        --todo: deduplicate
        local loclist = require("sting").location.shelf(winid, args.context.method)
        loclist:reset()
        loclist:extend(args.items)
        loclist:feed_vim(true, true)
      end
    end

    ---@param fname 'definition'|'type_definition'
    ---@param open_mode? infra.bufopen.Mode
    local function rhs_goto(fname, open_mode)
      local fn = assert(lsp.buf[fname])
      local on_list = make_onlist_fn(open_mode or "inplace")
      return function() fn({ on_list = on_list }) end
    end

    ---@param open_mode? infra.bufopen.Mode
    local function rhs_ref(open_mode)
      local on_list = make_onlist_fn(open_mode or "inplace")
      return function() lsp.buf.references(nil, { on_list = on_list }) end
    end

    function general_lsp.keymaps(bufnr)
      local bm = bufmap.wraps(bufnr)

      --comp,pum
      bm.i("<c-n>", "<c-x><c-o>")
      bm.i(".", ".<c-x><c-o>")
      bm.i("<c-j>", rhs_accept_first)
      bm.i("<cr>", rhs_accept_current)
      --no i_tab here, which is took by parrot

      bm.n("gd", rhs_goto("definition"))
      bm.n("<c-w>d", rhs_goto("definition", "right"))
      bm.n("<c-]>", rhs_goto("type_definition"))
      bm.n("<c-w>]", rhs_goto("type_definition", "right"))
      bm.n("gu", rhs_ref("inplace"))

      bm.n("K", function() require("optilsp.buf").hover() end)
      bm.n("gk", function() require("optilsp.buf").show_signature() end)
      bm.i("<c-k>", function() require("optilsp.buf").show_signature() end)
      bm.n("gr", function() require("optilsp.buf").rename() end)
      bm.n("ga", function() lsp.buf.code_action() end)
      bm.n("gO", function() lsp.buf.document_symbol() end)
      bm.n("gD", function() lsp.buf.type_definition() end)
    end
  end
end

---@type {[string]: {vim: fun(bufnr: number), treesitter?: fun(bufnr: number), lsp?: fun(bufnr: number)}}
local bufspecs = {}
do
  local function add(lang, spec)
    if bufspecs[lang] ~= nil then error(string.format("%s already exists in buf_specs", lang)) end
    bufspecs[lang] = spec
  end

  ---@diagnostic disable: unused-local

  -- langs
  add("lua", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.commentstring = [[-- %s]]
      bo.tabstop = 2
      bo.softtabstop = 2
      bo.shiftwidth = 2
      bo.expandtab = true
      bm.x("K", [[:lua require("helphelp").nvim()<cr>]])
      bm.n("gq", function()
        require("squirrel.sort_requires")(bufnr)
        require("sculptor").sculpt()
      end)
      bm.n("<leader>r", function() require("mill").run() end)
      bm.n("<leader>e", function() require("clinic").lint() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "lua")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("gx", function() require("squirrel.docgen.lua")() end)
        bm.x("g>", [[:lua require'squirrel.veil'.cover('lua')<cr>]])
        bm.n("vin", function() require("squirrel.incsel").n() end)
        bm.n("vim", function() require("squirrel.incsel").m("lua") end)
        bm.i("<c-;>", function() require("squirrel.fixends").lua() end)
        require("squirrel.jumps").attach("lua")
        bm.n("g?", function() require("squirrel.whereami")("lua") end)
        bm.n("<leader>i", function() require("squirrel.insert_import.lua")() end)
        fold_with_squirrel()
      end
    end,
    lsp = function(bufnr) --
      general_lsp.start("luals", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
      local bm = bufmap.wraps(bufnr)
      bm.i(":", ":<c-x><c-o>")
    end,
  })

  add("python", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".py"
      bo.comments = [[b:#,fb:-]]
      bo.commentstring = [[# %s]]
      bm.n("gq", function() require("sculptor").sculpt() end)
      bm.n("<leader>r", function() require("mill").run() end)
      bm.n("<leader>e", function() require("clinic").lint() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "python")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("<leader>i", function() require("squirrel.insert_import.python")() end)
        bm.n("vin", function() require("squirrel.incsel").n() end)
        bm.i("<c-'>", function() require("squirrel.fstr")() end)
        bm.i("<c-;>", function() require("squirrel.fixends").general() end)
        fold_with_squirrel()
      end
    end,
    lsp = function(bufnr) --
      general_lsp.start("ty", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
    end,
  })

  add("zig", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".zig"
      bo.commentstring = "// %s"
      bm.n("gq", function() require("sculptor").sculpt() end)
      bm.n("<leader>r", function() require("mill").run() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "zig")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.x("g>", [[:lua require'squirrel.veil'.cover('zig')<cr>]])
        bm.n("vin", function() require("squirrel.incsel").n() end)
        require("squirrel.jumps").attach("zig")
        fold_with_squirrel()
      end
    end,
    lsp = function(bufnr) --
      general_lsp.start("zls", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
    end,
  })

  add("bash", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".sh"
      bo.comments = [[b:#,fb:-]]
      bo.commentstring = [[# %s]]
      bm.n("<leader>r", function() require("mill").run() end)
      bm.n("<leader>e", function() require("clinic").lint() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "bash")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.x("g>", [[:lua require'squirrel.veil'.cover('sh')<cr>]])
      end
    end,
  })

  add("c", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".c"
      bo.commentstring = [[// %s]]
      bo.expandtab = true
      bo.cindent = true
      bm.n("gq", function() require("sculptor").sculpt() end)
      bm.n("<leader>r", function() require("mill").run() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "c")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.x("g>", [[:lua require'squirrel.veil'.cover('c')<cr>]])
        bm.n("vin", function() require("squirrel.incsel").n() end)
        bm.n("g?", function() require("squirrel.whereami")("c") end)
        fold_with_squirrel()
      end
    end,
    lsp = function(bufnr) --
      general_lsp.start("clangd", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
      local bm = bufmap.wraps(bufnr)
      bm.n("gq", function() vim.lsp.buf.format({ async = false }) end)
    end,
  })

  add("go", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".go"
      bo.commentstring = [[// %s]]
      bo.expandtab = false
      bm.n("gq", function() require("sculptor").sculpt() end)
      bm.n("<leader>r", function() require("mill").run() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "go")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("<leader>i", function() require("squirrel.insert_import.go")() end)
        bm.x("g>", [[:lua require'squirrel.veil'.cover('go')<cr>]])
        bm.n("vin", function() require("squirrel.incsel").n() end)
        bm.n("gx", function() require("squirrel.docgen.go")() end)
        fold_with_squirrel()
      end
    end,
    lsp = function(bufnr) --
      general_lsp.start("gopls", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
    end,
  })

  add("php", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.comments = [[s1:/*,mb:*,ex:*/,://,:#]]
      bo.commentstring = [[// %s]]
      bo.suffixesadd = ".php"
      -- php namespace, not fully support psr-0, psr-4
      --setl includeexpr=substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g')
      -- `yii => yii2`
      --bo.includeexpr = [[substitute(substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g'),'yii','yii2','')]]
      bm.n("<leader>r", function() require("mill").run() end)
    end,
    treesitter = function(bufnr) ts.start(bufnr, "php") end,
  })

  add("cpp", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".cpp"
      bo.commentstring = [[// %s]]
      bo.expandtab = true
      bo.cindent = true
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "cpp")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
        -- bm.n("g?", function() require("squirrel.whereami")('c') end)
      end
    end,
    lsp = function(bufnr)
      general_lsp.start("clangd", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
      local bm = bufmap.wraps(bufnr)
      bm.n("gq", function() vim.lsp.buf.format({ async = false }) end)
    end,
  })

  add("vim", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".vim"
      bo.commentstring = [[" %s]]
      bo.expandtab = true
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "vim")
      --the vim parser produce incorrect end range of body node sometimes,
      --so squirrel.incsel will not be available here
    end,
  })

  add("kotlin", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".kt"
      bo.commentstring = [[// %s]]
      bo.expandtab = true
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "kotlin")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
      end
    end,
  })

  add("fish", {
    vim = function(bufnr)
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      bo.suffixesadd = ".fish"
      bo.commentstring = [[# %s]]
      bm.n("<leader>r", function() require("mill").run() end)
      bm.n("gq", function() require("sculptor").sculpt() end)
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "fish")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
        bm.n("<leader>e", function() require("squirrel.saltedfish").lint() end)
      end
    end,
  })

  add("cmake", {
    lsp = function(bufnr)
      general_lsp.start("cmakels", bufnr)
      general_lsp.prefers(bufnr)
      general_lsp.keymaps(bufnr)
    end,
  })

  add("html", {
    treesitter = function(bufnr)
      ts.start(bufnr, "html")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
      end
    end,
  })

  add("javascript", {
    treesitter = function(bufnr)
      ts.start(bufnr, "javascript")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
      end
    end,
  })

  add("vue", {
    treesitter = function(bufnr)
      ts.start(bufnr, "vue")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
      end
    end,
  })

  add("glsl", {
    treesitter = function(bufnr)
      ts.start(bufnr, "glsl")
      do -- squirrel
        local bm = bufmap.wraps(bufnr)
        bm.n("vin", function() require("squirrel.incsel").n() end)
        fold_with_squirrel()
      end
    end,
  })

  -- misc
  add("json", {
    vim = function(bufnr)
      local bm = bufmap.wraps(bufnr)
      bm.n("gq", "<cmd>%! jq .<cr>")
    end,
    treesitter = function(bufnr)
      ts.start(bufnr, "json")
      local bm = bufmap.wraps(bufnr)
      bm.n("g?", function() require("squirrel.whereami")("json") end)
      fold_with_squirrel()
    end,
  })

  add("git", {
    vim = function(bufnr)
      local bo = prefer.buf(bufnr)
      bo.syntax = "git"
      ex("runtime", "syntax/git.vim")
    end,
  })

  add("gitcommit", {
    vim = function(bufnr)
      local bo = prefer.buf(bufnr)
      bo.syntax = "gitcommit"
      ex("runtime", "syntax/gitcommit.vim")
    end,
  })

  add("help", {
    vim = function(bufnr)
      local bo = prefer.buf(bufnr)
      bo.bufhidden = "wipe"
      bo.keywordprg = ":help"
    end,
  })

  add("man", {
    vim = function(bufnr)
      local bo = prefer.buf(bufnr)
      bo.bufhidden = "wipe"
      bo.keywordprg = ":Man"

      local bm = bufmap.wraps(bufnr)
      bm.n("q", [[<cmd>quit<cr>]])
    end,
  })

  add("qf", {
    vim = function(bufnr)
      local rhs = require("sting.rhs")
      local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
      ex("runtime", "syntax/qf.vim")
      ---accessible
      bm.n("q", "<cmd>q<cr>")
      bm.n("<c-[>", "<cmd>q<cr>")
      bm.n("o", function() rhs.split("below") end)
      bm.n("O", function() rhs.split("above") end)
      bm.n("v", function() rhs.split("right") end)
      bm.n("<c-/>", function() rhs.split("right") end)
      --
      bm.n("p", function() rhs.preview() end)
      bm.n("i", function() rhs.open() end)
      bm.n("<cr>", function() rhs.open() end)
      --
    end,
  })

  add("make", {
    vim = function(bufnr)
      local bo = prefer.buf(bufnr)
      bo.expandtab = false
    end,
  })

  add("wiki", {
    vim = function(bufnr, winid)
      require("wiki").attach(bufnr)
      bufmap(bufnr, "i", "<c-;>", function() require("squirrel.fixends").general() end)
    end,
  })

  add("sshconfig", { --
    vim = function(bufnr) prefer.bo(bufnr, "commentstring", "# %s") end,
  })
end

---@type {[string]: {vim:fun(bufnr:integer), treesitter:fun(bufnr:integer)}}
local winspecs = {
  lua = { vim = function() setlocal("list") end },
  git = { vim = function() setlocal("list") end },
  help = { vim = function() setlocal("conceallevel=0") end },
  make = { vim = function() setlocal("nolist") end },
  wiki = { vim = function() setlocal("conceallevel=3") end },
  man = { vim = function() setlocal("nonumber", "norelativenumber") end },
}

do -- main
  local aug = augroups.Augroup("hal://langs")
  aug:repeats("FileType", {
    desc = "per lang spec",
    callback = function(args)
      local bufnr, ft = args.buf, args.match
      do
        local spec = bufspecs[ft]
        if spec == nil then goto next end
        if spec.vim then spec.vim(bufnr) end
        if profiles.has("treesit") and spec.treesitter then spec.treesitter(bufnr) end
        if profiles.has("lsp") and spec.lsp then spec.lsp(bufnr) end
        ::next::
      end
      do
        local spec = winspecs[ft]
        if spec == nil then goto next end
        if spec.vim then spec.vim(bufnr) end
        if profiles.has("treesit") and spec.treesitter then spec.treesitter(bufnr) end
        ::next::
      end
    end,
  })
end
