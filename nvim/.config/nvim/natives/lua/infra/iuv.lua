---succeed or scream(哎呦喂)
---see `:h luv-error-handling`

local setlib = require("infra.setlib")

local uv = vim.uv

local allows = setlib.new(
  "fs_close",
  "fs_fstat",
  "fs_open",
  "fs_read",
  "fs_rename",
  "fs_stat",
  "fs_realpath",
  "fs_unlink",
  "fs_write",
  "fs_scandir",
  "new_pipe",
  "new_tcp",
  "new_timer",
  "pipe_connect",
  "queue_work",
  "read_start",
  "tcp_connect",
  "timer_start",
  "timer_stop",
  "write"
)

return setmetatable({}, {
  __index = function(t, api)
    assert(allows[api])

    local impl = assert(uv[api])

    local function wrapped(...)
      local result, err = impl(...)
      if result == nil then error(err) end
      return result
    end

    rawset(t, api, wrapped)

    return wrapped
  end,
})
