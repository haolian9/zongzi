local M = {}

local jelly = require("infra.jellyfish")("plugin.awesome")

local api = vim.api

local nmap = function(lhs, rhs)
  vim.api.nvim_set_keymap("n", lhs, rhs, { silent = false, noremap = true })
end

local usercmd = api.nvim_create_user_command

local function vmap_silent(lhs, rhs)
  vim.api.nvim_set_keymap("v", lhs, rhs, { silent = true })
end

function M.setup()
  require("fzf.setup")()

  api.nvim_set_option("tabline", [[%!v:lua.require'tabline'.render()]])
  api.nvim_set_option("statusline", [[%!v:lua.require'statusline'.render()]])

  do
    nmap([[<leader>q]], [[<cmd>lua require'qltoggle'.toggle_qflist()<cr>]])
    nmap([[<leader>l]], [[<cmd>lua require'qltoggle'.toggle_loclist()<cr>]])
    nmap([[<leader>`]], [[<cmd>lua require'popupshell'.floatwin()<cr>]])
  end

  -- stylua: ignore
  do
    local comp_bufname = function()
      local name = vim.fn.expand("%:t")
      if name == "[Command Line]" and vim.bo.filetype == "vim" then name = vim.fn.expand("#:t") end
      return { name }
    end

    usercmd("Touch", function(args) require("infra.coreutils").relative_touch(args.args) end, { nargs = 1, complete = comp_bufname })
    usercmd("Mv", function(args) require("infra.coreutils").rename_filebuf(0, args.args) end, { nargs = 1, complete = comp_bufname })
    usercmd("Rm", function() require("infra.coreutils").rm_filebuf(0) end, { nargs = 0 })
    usercmd("Mkdir", function(args) require('infra.coreutils').relative_mkdir(args.args) end, {nargs = 1})
  end

  do
    vmap_silent([[*]], [[:lua require"infra.vsel".search_forward()<cr>]])
    vmap_silent([[#]], [[:lua require"infra.vsel".search_backward()<cr>]])
    vmap_silent([[<leader>s]], [[:lua require"infra.vsel".substitute()<cr>]])
  end

  do
    nmap([[<leader>/]], [[<cmd>lua require("grep").rg.input('repo')<cr>]])
    vmap_silent([[<leader>/]], [[:lua require("grep").rg.vsel('repo')<cr>]])
    usercmd("Todo", function()
      -- patterns: `todo`, `todo@haoliang`
      require("grep").rg.text("repo", [[\btodo@?]])
    end, { nargs = 0 })
  end

  for i = 1, 9 do
    nmap(string.format([[<leader>%d]], i), string.format([[<cmd>lua require'winjump'.to(%d)<cr>]], i))
  end

  do
    nmap("-", [[<cmd>lua require'kite'.fly()<cr>]])
    nmap("_", [[<cmd>lua require'kite'.land()<cr>]])
    nmap("[k", [[<cmd>lua require'kite'.rhs_open_sibling_file('prev')<cr>]])
    nmap("]k", [[<cmd>lua require'kite'.rhs_open_sibling_file('next')<cr>]])
  end

  do
    api.nvim_set_keymap("n", "gq", [[<cmd>lua require'formatter'.run()<cr>]], { noremap = true })
    api.nvim_set_keymap("n", "<leader>r", [[<cmd>lua require'windmill'.autorun()<cr>]], {})
  end

  do
    nmap([[<leader>s]], [[<cmd>lua require'fzf'.files()<cr>]])
    nmap([[<leader>g]], [[<cmd>lua require'fzf'.tracked()<cr>]])
    nmap([[<leader>b]], [[<cmd>lua require'fzf'.buffers()<cr>]])
    nmap([[<leader>u]], [[<cmd>lua require'fzf'.modified()<cr>]])
    nmap([[<leader>m]], [[<cmd>lua require'fzf'.mru()<cr>]])
    nmap([[<leader>f]], [[<cmd>lua require'fzf'.siblings()<cr>]])
    nmap([[<leader>d]], [[<cmd>lua require'fzf'.symbols()<cr>]])
    nmap([[<leader>w]], [[<cmd>lua require'fzf'.windows()<cr>]])
    -- fresh version
    nmap([[\s]], [[<cmd>lua require'fzf'.files(false)<cr>]])
    nmap([[\g]], [[<cmd>lua require'fzf'.tracked(false)<cr>]])
    nmap([[\f]], [[<cmd>lua require'fzf'.siblings(false)<cr>]])
    nmap([[\d]], [[<cmd>lua require'fzf'.symbols(false)<cr>]])
  end

  -- misc usercmd
  -- stylua: ignore
  do
    usercmd("Nag", function(args)
      local name = args.args == "" and "tab" or args.args
      local fn = require("nag")[name]
      if fn == nil then return jelly.err("nag has no such split cmd: %s", name) end
      fn()
    end, { nargs = "*", range = true, complete = function() return { "tab", "split", "vsplit" } end })
    usercmd("Resize", function() require("winresize")() end, { nargs = 0 })
    usercmd("Pstree", function(args) require("pstree").run(args.fargs) end, { nargs = "*" })
    usercmd("Punctuate", function() require("punctconv").multiline_vsel() end, { nargs = 0, range = true })
    usercmd("Zoom", function() require("winzoom")() end, { nargs = 0 })
  end

  api.nvim_set_keymap("n", "<leader>.", [[<cmd>lua require'reveal'()<cr>]], {})
end

return M
