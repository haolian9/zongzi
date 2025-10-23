do --- Default autocommands. See |default-autocmds|
  local aug = vim.api.nvim_create_augroup("vim://term", {})

  vim.api.nvim_create_autocmd("TermRequest", {
    group = aug,
    desc = "Handles OSC foreground/background color requests",
    callback = function(args)
      --- @type integer
      local channel = vim.bo[args.buf].channel
      if channel == 0 then return end
      local fg_request = args.data == "\027]10;?"
      local bg_request = args.data == "\027]11;?"
      if fg_request or bg_request then
        -- WARN: This does not return the actual foreground/background color,
        -- but rather returns:
        --   - fg=white/bg=black when Nvim option 'background' is 'dark'
        --   - fg=black/bg=white when Nvim option 'background' is 'light'
        local red, green, blue = 0, 0, 0
        local bg_option_dark = vim.go.background == "dark"
        if (fg_request and bg_option_dark) or (bg_request and not bg_option_dark) then
          red, green, blue = 65535, 65535, 65535
        end
        local command = fg_request and 10 or 11
        local data = string.format("\027]%d;rgb:%04x/%04x/%04x\007", command, red, green, blue)
        vim.api.nvim_chan_send(channel, data)
      end
    end,
  })
end
