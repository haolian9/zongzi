local M = {}

local fn = require("infra.fn")
local logging = require("infra.logging")
local unsafe = require("infra.unsafe")
local tail = require("infra.tail")

local uv = vim.loop

local facts = {
  stdout_fpath = logging.newfile("infra.subprocess"),
}

local signals = {
  terminate = 15,
  kill = 9,
  interrupt = 2,
}
_ = signals

local function blocking_wait(pid)
  local waited_pid, status
  while true do
    waited_pid, status = unsafe.waitpid(pid, true)
    if waited_pid == 0 then
      vim.wait(50)
    elseif waited_pid == -1 then
      -- could be: ECHLD
      break
    else
      assert(waited_pid == pid)
      assert(unsafe.WIFEXITED(status))
      break
    end
  end
  return waited_pid, status
end

local redirect_to_file = (function()
  -- NB: meant to be dangling; writes can be interleaving between subprocesses
  local fd = uv.fs_open(facts.stdout_fpath, "a", tonumber("600", 8))

  ---@param done function|nil
  return function(read_pipe, done)
    uv.read_start(read_pipe, function(err, data)
      assert(not err, err)
      if data then
        uv.fs_write(fd, data)
      else
        read_pipe:close()
        if done ~= nil then done() end
      end
    end)
  end
end)()

-- each chunk of read from stdout can contains multiple lines, and may not ends with `\n`
---@param chunks table @list of chunks
function M.split_stdout(chunks)
  local del = "\n"
  local chunk_iter = fn.list_iter(chunks)
  local line_iter = nil
  local short = nil

  return function()
    while true do
      if line_iter == nil then
        local chunk = chunk_iter()
        if chunk == nil then return end
        line_iter = fn.split_iter(chunk, del, nil, true)
      end

      local line = line_iter()
      if line ~= nil then
        if line:sub(#line) == del then
          if short ~= nil then
            line = short .. line
            short = nil
          end
          return line:sub(0, #line - 1)
        else
          -- last part but not a complete line
          assert(short == nil)
          short = line
        end
      else
        line_iter = nil
      end
    end
  end
end

---@param cmd string
---@param opts table|nil
---@param capture_stdout boolean|nil @nil=false
function M.run(cmd, opts, capture_stdout)
  opts = opts or {}
  if capture_stdout == nil then capture_stdout = false end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()
  local rc

  opts["stdio"] = { nil, stdout, stderr }

  local _, pid = uv.spawn(cmd, opts, function(code, signal)
    rc = code
    local _ = signal
  end)

  local stdout_lines
  if capture_stdout then
    local chunks = {}
    uv.read_start(stdout, function(err, data)
      assert(not err, err)
      if data then
        table.insert(chunks, data)
      else
        stdout:close()
      end
    end)
    stdout_lines = M.split_stdout(chunks)
  else
    redirect_to_file(stdout)
  end

  redirect_to_file(stderr)

  local wpid, wstatus = blocking_wait(pid)
  -- there is a race condition on waitpid between uv.spawn and blocking_wait
  if wpid == -1 then
    assert(rc ~= nil)
    return { pid = pid, exit_code = rc, stdout = "" }
  else
    return { pid = pid, exit_code = unsafe.WEXITSTATUS(wstatus), stdout = stdout_lines }
  end
end

---@param cmd string
---@param opts table|nil
function M.asyncrun(cmd, opts, stdout_callback, exit_callback)
  assert(stdout_callback ~= nil and exit_callback)
  opts = opts or {}

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  opts["stdio"] = { nil, stdout, stderr }

  uv.spawn(cmd, opts, function(code, signal)
    local _ = signal
    exit_callback(code)
  end)

  local chunks = {}
  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      table.insert(chunks, data)
    else
      stdout:close()
      vim.schedule(function()
        stdout_callback(M.split_stdout(chunks))
      end)
    end
  end)

  redirect_to_file(stderr)
end

function M.tail_logs()
  tail.split_below(facts.stdout_fpath)
end

return M
