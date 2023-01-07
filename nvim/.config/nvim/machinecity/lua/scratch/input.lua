local M = {}

local api = vim.api

local defaults = {
  prompt = "",
  mask_fn = function(char, code)
    -- a-z
    return code >= 0x61 and code <= 0x7a
  end,
  then_fn = function(text)
    print(string.format('got "%s"', text))
  end,
}

M.main = function(prompt, mask_fn, then_fn)
  -- todo: max inputs
  -- todo: getchar
  prompt = prompt or defaults.prompt
  mask_fn = mask_fn or defaults.mask_fn
  then_fn = then_fn or defaults.then_fn

  local bufnr = nil
  do
    bufnr = api.nvim_create_buf(false, true)
    assert(bufnr ~= 0)

    api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    api.nvim_buf_set_option(bufnr, "buftype", "prompt")
    fn.prompt_setprompt(bufnr, prompt)

    api.nvim_buf_set_var(bufnr, "a.i.interrupted", false)
    api.nvim_buf_set_var(bufnr, "a.i.finished", false)

    api.nvim_buf_set_keymap(bufnr, "i", [[<c-n>]], [[<c-x><c-v>]], { noremap = true })
  end

  local win_id = nil
  do
    -- todo: dynamic col expanding
    win_id = api.nvim_open_win(bufnr, true, {
      relative = "cursor",
      width = 20,
      height = 1,
      row = 1,
      col = 0,
      style = "minimal",
    })
    assert(win_id ~= 0)

    api.nvim_create_autocmd("WinLeave", {
      callback = function(event)
        if event.buf ~= bufnr then return end
        if api.nvim_buf_get_var(bufnr, "a.i.finished") then return true end
        api.nvim_buf_set_var(bufnr, "a.i.interrupted", true)
        api.nvim_win_close(win_id, true)
        return true
      end,
    })
  end

  do
    api.nvim_create_autocmd("InsertCharPre", {
      buffer = bufnr,
      callback = function(event)
        if event.buf ~= bufnr then return end
        if #vim.v.char ~= 1 then return end

        local char = vim.v.char
        local code = string.byte(char)

        -- treat space as cr
        if code == 0x20 then
          vim.v.char = ""
          api.nvim_input("<cr>")
          return
        end

        if not mask_fn(char, code) then
          vim.v.char = ""
          return
        end
      end,
    })

    vim.fn.prompt_setcallback(bufnr, function(text)
      assert(not api.nvim_buf_get_var(bufnr, "a.i.interrupted"), "interrupted should never be set before invoking this callback")

      api.nvim_buf_set_var(bufnr, "a.i.finished", true)
      api.nvim_win_close(win_id, true)

      then_fn(text)
    end)
  end

  api.nvim_command("startinsert")
end

return M
