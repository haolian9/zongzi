local Augroup = require("infra.Augroup")
local ex = require("infra.ex")
local fn = require("infra.fn")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local project = require("infra.project")

local langserspecs = require("langserspecs")
local profiles = require("profiles")

local api = vim.api
local ts = vim.treesitter

---@diagnostic disable: unused-local

---@type {[string]: {vim: fun(bufnr: number), treesitter?: fun(bufnr: number), lsp?: fun(bufnr: number)}}
local buf_specs = {}
do
  local function adds(new)
    for k, v in pairs(new) do
      if buf_specs[k] ~= nil then error(string.format("%s already exists in buf_specs", k)) end
      buf_specs[k] = v
    end
  end

  local resolve_root_dir
  do
    local home = assert(os.getenv("HOME"))
    local excludes = fn.toset({ home, "/srv/playground" })

    ---@return string? @nil=single file mode if the langser supports
    function resolve_root_dir()
      local root

      root = project.git_root()
      if root ~= nil then return root end

      root = project.working_root()
      if excludes[root] then return end

      return root
    end
  end

  -- langs
  adds({
    lua = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.commentstring = [[-- %s]]
        bo.tabstop = 2
        bo.softtabstop = 2
        bo.shiftwidth = 2
        bo.expandtab = true
        bm.x("K", [[:lua require("help").nvim()<cr>]])
        bm.n("gq", function()
          require("squirrel.sort_requires")(bufnr)
          require("morphling").morph()
        end)
        bm.n("<leader>r", function() require("windmill").ftrun() end)
        bm.n("<leader>e", function() require("cotton").lint() end)
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
          bm.n("g?", function() require("squirrel.whereami.lua")() end)
          bm.n("<leader>i", function() require("squirrel.insert_import.lua")() end)
        end
      end,
      lsp = function(bufnr) vim.lsp.start(langserspecs("luals", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr }) end,
    },
    python = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".py"
        bo.comments = [[b:#,fb:-]]
        bo.commentstring = [[# %s]]
        bm.n("gq", function() require("morphling").morph() end)
        bm.n("<leader>r", function() require("windmill").ftrun() end)
        bm.n("<leader>e", function() require("cotton").lint() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "python")
        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.n("<leader>i", function() require("squirrel.insert_import.general")() end)
          bm.n("vin", function() require("squirrel.incsel").n() end)
          bm.i("<c-'>", function() require("squirrel.fstr")() end)
          bm.i("<c-;>", function() require("squirrel.fixends").general() end)
        end
      end,
      lsp = function(bufnr) vim.lsp.start(langserspecs("pyright", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr }) end,
    },
    zig = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".zig"
        bo.commentstring = "// %s"
        bm.n("gq", function() require("morphling").morph() end)
        bm.n("<leader>r", function() require("windmill").ftrun() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "zig")
        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.x("g>", [[:lua require'squirrel.veil'.cover('zig')<cr>]])
          bm.n("vin", function() require("squirrel.incsel").n() end)

          require("squirrel.jumps").attach("zig")
        end
      end,
      lsp = function(bufnr) vim.lsp.start(langserspecs("zls", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr }) end,
    },
    bash = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".sh"
        bo.comments = [[b:#,fb:-]]
        bo.commentstring = [[# %s]]
        bm.n("<leader>r", function() require("windmill").ftrun() end)
        bm.n("<leader>e", function() require("cotton").lint() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "bash")
        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.x("g>", [[:lua require'squirrel.veil'.cover('sh')<cr>]])
        end
      end,
    },
    c = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".c"
        bo.commentstring = [[// %s]]
        bo.expandtab = true
        bo.cindent = true
        bm.n("gq", function() require("morphling").morph() end)
        bm.n("<leader>r", function() require("windmill").ftrun() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "c")
        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.x("g>", [[:lua require'squirrel.veil'.cover('c')<cr>]])
          bm.n("vin", function() require("squirrel.incsel").n() end)
          bm.n("g?", function() require("squirrel.whereami.c")() end)
        end
      end,
      lsp = function(bufnr)
        local bm = bufmap.wraps(bufnr)
        bm.n("gq", function() vim.lsp.buf.format({ async = false }) end)
        vim.lsp.start(langserspecs("clangd", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr })
      end,
    },
    go = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".go"
        bo.commentstring = [[// %s]]
        bo.expandtab = false
        bm.n("gq", function() require("morphling").morph() end)
        bm.n("<leader>r", function() require("windmill").ftrun() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "go")
        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.n("<leader>i", function() require("squirrel.insert_import.general")() end)
          bm.x("g>", [[:lua require'squirrel.veil'.cover('go')<cr>]])
          bm.n("vin", function() require("squirrel.incsel").n() end)
          bm.n("gx", function() require("squirrel.docgen.go")() end)
        end
      end,
      lsp = function(bufnr) vim.lsp.start(langserspecs("gopls", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr }) end,
    },
    php = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.comments = [[s1:/*,mb:*,ex:*/,://,:#]]
        bo.commentstring = [[// %s]]
        bo.suffixesadd = ".php"
        -- php namespace, not fully support psr-0, psr-4
        --setl includeexpr=substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g')
        -- `yii => yii2`
        --bo.includeexpr = [[substitute(substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g'),'yii','yii2','')]]
        bm.n("<leader>r", function() require("windmill").ftrun() end)
      end,
      treesitter = function(bufnr) ts.start(bufnr, "php") end,
    },
    cpp = {
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
          -- bm.n("g?", function() require("squirrel.whereami.c")() end)
        end
      end,
      lsp = function(bufnr)
        local bm = bufmap.wraps(bufnr)
        bm.n("gq", function() vim.lsp.buf.format({ async = false }) end)
        vim.lsp.start(langserspecs("clangd", resolve_root_dir(), profiles.has("powersave")), { bufnr = bufnr })
      end,
    },
    vim = {
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
    },
    kotlin = {
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
    },
    fish = {
      vim = function(bufnr)
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        bo.suffixesadd = ".fish"
        bo.commentstring = [[# %s]]

        bm.n("gq", function() require("morphling").morph() end)
      end,
      treesitter = function(bufnr)
        ts.start(bufnr, "fish")

        do -- squirrel
          local bm = bufmap.wraps(bufnr)
          bm.n("vin", function() require("squirrel.incsel").n() end)
        end
      end,
    },
  })
  -- misc
  adds({
    json = {
      vim = function(bufnr)
        local bm = bufmap.wraps(bufnr)
        bm.n("gq", "<cmd>%! jq .<cr>")
      end,
      treesitter = function(bufnr) ts.start(bufnr, "json") end,
    },
    git = {
      vim = function(bufnr)
        local bo = prefer.buf(bufnr)
        bo.syntax = "git"
        ex("runtime syntax/git.vim")
      end,
    },
    gitcommit = {
      vim = function(bufnr)
        local bo = prefer.buf(bufnr)
        bo.syntax = "gitcommit"
        ex("runtime syntax/gitcommit.vim")
      end,
    },
    help = {
      vim = function(bufnr)
        local bo = prefer.buf(bufnr)
        bo.bufhidden = "wipe"
        bo.keywordprg = ":help"
      end,
    },
    man = {
      vim = function(bufnr)
        local bo = prefer.buf(bufnr)
        bo.bufhidden = "wipe"
        bo.keywordprg = ":Man"

        local bm = bufmap.wraps(bufnr)
        bm.n("q", [[<cmd>quit<cr>]])
      end,
    },
    qf = {
      vim = function(bufnr)
        local rhs = require("sting.rhs")
        local bo, bm = prefer.buf(bufnr), bufmap.wraps(bufnr)
        ex("runtime syntax/qf.vim")
        ---accessible
        bm.n("q", "<cmd>q<cr>")
        bm.n("<c-[>", "<cmd>q<cr>")
        bm.n("i", "<cr>")
        bm.n("o", function() rhs.split("below") end)
        bm.n("O", function() rhs.split("above") end)
        bm.n("v", function() rhs.split("right") end)
        bm.n("<c-/>", function() rhs.split("right") end)
      end,
    },
    make = {
      vim = function(bufnr)
        local bo = prefer.buf(bufnr)
        bo.expandtab = false
      end,
    },
    wiki = {
      vim = function(bufnr, winid)
        require("wiki").attach(bufnr)
        bufmap(bufnr, "i", "<c-;>", function() require("squirrel.fixends").general() end)
      end,
    },
    sshconfig = { vim = function(bufnr) prefer.bo(bufnr, "commentstring", "# %s") end },
  })
end

local win_specs = {
  lua = {
    vim = function(bufnr, winid) prefer.wo(winid, "list", true) end,
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "lua") end,
  },
  python = {
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "python") end,
  },
  zig = {
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "zig") end,
  },
  c = {
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "c") end,
  },
  go = {
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "go") end,
  },
  json = {
    treesitter = function(bufnr, winid) require("squirrel.folding").attach(winid, "json") end,
  },
  git = { vim = function(bufnr, winid) prefer.wo(winid, "list", false) end },
  help = { vim = function(bufnr, winid) prefer.wo(winid, "conceallevel", 0) end },
  wiki = { vim = function(bufnr, winid) prefer.bo(bufnr, "conceallevel", 3) end },
  man = {
    vim = function(bufnr, winid)
      local wo = prefer.win(winid)
      wo.number = false
      wo.relativenumber = false
    end,
  },
}

do -- main
  local aug = Augroup("boot://langspecs")

  aug:repeats("FileType", {
    desc = "per lang spec: buf-local",
    callback = function(args)
      local bufnr, ft = args.buf, args.match
      local spec = buf_specs[ft]
      if spec == nil then return end
      spec.vim(bufnr)
      if profiles.has("treesitter") and spec.treesitter then spec.treesitter(bufnr) end
      if profiles.has("lsp") and spec.lsp then spec.lsp(bufnr) end
    end,
  })

  aug:repeats({ "WinNew", "BufWinEnter" }, {
    desc = "per lang spec: win-local",
    callback = function(args)
      local bufnr, winid = args.buf, api.nvim_get_current_win()
      local ft = prefer.bo(bufnr, "filetype")
      local spec = win_specs[ft]
      if spec == nil then return end
      if spec.vim then spec.vim(bufnr, winid) end
      if profiles.has("treesitter") and spec.treesitter then spec.treesitter(bufnr, winid) end
      if profiles.has("lsp") and spec.lsp then spec.lsp(bufnr, winid) end
    end,
  })
end
