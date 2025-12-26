--- Default autocommands. See |default-autocmds|
do
  local aug = vim.api.nvim_create_augroup("nvim.terminal", {})

  vim.api.nvim_create_autocmd("TermRequest", {
    group = aug,
    desc = "Handles OSC foreground/background color requests",
    callback = function(args)
      --- @type integer
      local channel = vim.bo[args.buf].channel
      if channel == 0 then return end
      local fg_request = args.data.sequence == "\027]10;?"
      local bg_request = args.data.sequence == "\027]11;?"
      if fg_request or bg_request then
        -- WARN: This does not return the actual foreground/background color,
        -- but rather returns:
        --   - fg=white/bg=black when Nvim option 'background' is 'dark'
        --   - fg=black/bg=white when Nvim option 'background' is 'light'
        local red, green, blue = 0, 0, 0
        local bg_option_dark = vim.o.background == "dark"
        if (fg_request and bg_option_dark) or (bg_request and not bg_option_dark) then
          red, green, blue = 65535, 65535, 65535
        end
        local command = fg_request and 10 or 11
        local data = string.format("\027]%d;rgb:%04x/%04x/%04x\007", command, red, green, blue)
        vim.api.nvim_chan_send(channel, data)
      end
    end,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    group = aug,
    desc = "Default settings for :terminal buffers",
    callback = function(args)
      local prefer = require("infra.prefer")
      local bo = prefer.buf(args.buf)
      bo.modifiable = false
      bo.undolevels = -1
      bo.scrollback = vim.o.scrollback < 0 and 10000 or math.max(1, vim.o.scrollback)
      bo.textwidth = 0
      local wo = prefer.win(vim.api.nvim_get_current_win())
      wo.wrap = false
      wo.list = false
      wo.number = false
      wo.relativenumber = false
      wo.signcolumn = "no"
      wo.foldcolumn = "0"
    end,
  })

  vim.api.nvim_create_autocmd("CmdwinEnter", {
    pattern = "[:>]",
    desc = "Limit syntax sync to maxlines=1 in the command window",
    group = vim.api.nvim_create_augroup("nvim.cmdwin", {}),
    command = "syntax sync minlines=1 maxlines=1",
  })
end
