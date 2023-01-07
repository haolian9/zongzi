local M = {}

M.watch_buf_events = function()
  local logging = require("infra.logging")

  local file, open_err = assert(io.open(logging.newfile("watch.events"), "w"))
  assert(open_err == nil, open_err)

  local function record_event(args)
    -- format: { buf = 3, event = "BufWipeout", file = "", id = 11, match = "" }

    local record = string.format("[%s] id=%d, event=%s, buf=%d, file=%s, match=%s\n", vim.fn.strftime("%H:%M:%S"), args.id, args.event, args.buf, vim.inspect(args.file), vim.inspect(args.match))

    local _, write_err = file:write(record)
    assert(write_err == nil, write_err)
    file:flush()
  end

  vim.api.nvim_create_autocmd({
    "BufAdd",
    "BufDelete",
    "BufEnter",
    "BufFilePost",
    "BufFilePre",
    "BufHidden",
    "BufLeave",
    "BufModifiedSet",
    "BufNew",
    "BufNewFile",
    "BufRead",
    "BufReadPost",
    "BufReadCmd",
    "BufReadPre",
    "BufUnload",
    "BufWinEnter",
    "BufWinLeave",
    "BufWipeout",
    "BufWrite",
    "BufWritePre",
    "BufWriteCmd",
    "BufWritePost",
    "WinClosed",
    "WinEnter",
    "WinLeave",
    "WinNew",
    "ColorScheme",
  }, { callback = record_event })
end

M.prompt_close = function(bufnr) end

M.prompt = function()
  local ns_id = vim.api.nvim_create_namespace("scratchpad.prompt")

  local bufnr = nil
  do
    bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0)
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")

    vim.fn.prompt_setprompt(bufnr, "> ")

    -- register
    -- > WinEnter, InsertEnter
    -- unregister
    -- > WinLeave, InsertLeave (c-o)

    vim.api.nvim_create_autocmd("InsertCharPre", {
      buffer = bufnr,
      callback = function(event)
        if event.buf ~= bufnr then return end
        if #vim.v.char ~= 1 then return end
        local code = string.byte(vim.v.char)
        if code >= 0x61 and code <= 0x7a then
          -- a-z
          return
        end
        -- discard any other chars
        vim.v.char = ""
      end,
    })
  end

  local win_id = nil
  do
    win_id = vim.api.nvim_open_win(bufnr, true, {
      relative = "cursor",
      width = 20,
      height = 1,
      row = 1,
      col = 0,
      style = "minimal",
    })
    assert(win_id ~= 0)
  end

  do
    -- vim.api.nvim_buf_set_keymap(bufnr, "i", [[<cr>]], [[<cr><cmd>quit!<cr>]], { noremap = true })
    vim.fn.prompt_setcallback(bufnr, function(text)
      print("reset on_key")
      vim.on_key(nil, ns_id)
      vim.cmd("q!")
      -- vim.api.nvim_buf_delete(bufnr, { force = true })
      -- vim.api.nvim_win_close(win_id, true)
      print("got", type(text), "'" .. text .. "'")
    end)
    --vim.on_key(function(char)
    --  vim.api.nvim_buf_set_lines(bufnr, -1, 0, true, { "" })
    --  --local code = string.byte(char)
    --  ---- number: code >= 0x30 and code <= 0x39 then
    --  ---- A-Z: code >= 0x41 and code <= 0x5a
    --  --if code >= 0x61 and code <= 0x7a then
    --  --  -- a-z
    --  --elseif code == 0x20 then
    --  --  -- treat space as cr
    --  --  -- vim.api.nvim_input("\r")
    --  --  vim.on_key(nil, ns_id)
    --  --  return
    --  --elseif code == 0x21 then
    --  --  -- cr
    --  --elseif code == 0x08 then
    --  --  -- bs
    --  --else
    --  --  -- invalid char
    --  --  --vim.api.nvim_input("\b")
    --  --end
    --  --print("-", char)
    --end, ns_id)

    vim.cmd("startinsert")
  end
end

do
  local count = 0

  -- test state of v:lua, luaeval
  function M.hello()
    count = count + 1
    return string.format("#%d hello", count)
  end
end

return M
