local M = {}

local ropes = require("string.buffer")

local itertools = require("infra.itertools")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("infra.subprocess", "info")
local logging = require("infra.logging")
local strlib = require("infra.strlib")
local tail = require("infra.tail")

local uv = vim.uv

local facts = {
  stdout_fpath = logging.newfile("infra.subprocess"),
  forever = math.pow(2, 31) - 1,
}

local redirect_to_file
do
  -- NB: meant to be dangling; writes can be interleaving between subprocesses
  local fd = iuv.fs_open(facts.stdout_fpath, "a", tonumber("600", 8))

  ---@param done function|nil
  function redirect_to_file(read_pipe, done)
    iuv.read_start(read_pipe, function(err, data)
      assert(not err, err)
      if data then
        iuv.fs_write(fd, data)
      else
        read_pipe:close()
        if done ~= nil then done() end
      end
    end)
  end
end

-- each chunk of read from stdout can contains multiple lines, and may not ends with `\n`
---@param chunks string[]
function M.iter_lines(chunks)
  local del = "\n"
  local chunk_iter = itertools.iter(chunks)
  local line_iter = nil
  local short = ropes.new(4096)

  return function()
    while true do
      if line_iter == nil then
        local chunk = chunk_iter()
        if chunk == nil then
          if #short == 0 then return end
          return short:get()
        end
        line_iter = strlib.iter_splits(chunk, del, nil, true)
      end

      local line = line_iter()
      if line == nil then
        line_iter = nil
        goto continue
      end

      if strlib.endswith(line, del) then
        local this_line = string.sub(line, 1, #line - #del)
        if #short == 0 then return this_line end
        return short:put(this_line):get()
      else
        short:put(line)
      end

      ::continue::
    end
  end
end

---@class infra.subprocess.SpawnOpts
---@field args string[]
---@field env? string[] @NB: not {key: val}
---@field cwd? string
---@field detached? boolean

---@class infra.subprocess.CompletedProc
---@field pid integer
---@field exit_code integer
---@field stdout fun():string?

---CAUTION: when capture_stdout=raw, the `\n` ending can cause trouble
---@param bin string
---@param opts? infra.subprocess.SpawnOpts
---@param capture_stdout 'raw'|'lines'|false|nil @nil=false
---@return infra.subprocess.CompletedProc
function M.run(bin, opts, capture_stdout)
  opts = opts or {}
  if capture_stdout == nil then capture_stdout = false end

  local stdout = iuv.new_pipe()
  local stderr = iuv.new_pipe()
  local rc

  opts["stdio"] = { nil, stdout, stderr }

  local proc_t, pid = uv.spawn(bin, opts, function(code) rc = assert(code) end)
  if proc_t == nil then return jelly.fatal("SpawnError", "bin=%s, opts=%s", bin, opts) end

  local stdout_iter
  if not capture_stdout then
    redirect_to_file(stdout)
    stdout_iter = function() end
  else
    ---@type string[]
    local chunks = {}
    iuv.read_start(stdout, function(err, data)
      assert(not err, err)
      if data then
        table.insert(chunks, data)
      else
        stdout:close()
      end
    end)
    if capture_stdout == "raw" then
      stdout_iter = itertools.iter(chunks)
    else
      stdout_iter = M.iter_lines(chunks)
    end
  end

  redirect_to_file(stderr)

  vim.wait(facts.forever, function() return rc ~= nil end, 100)

  return { pid = pid, exit_code = rc, stdout = stdout_iter }
end

---@param bin string
---@param opts infra.subprocess.SpawnOpts
---@param on_stdout fun(data: string|nil) @nil=closed
---@param on_exit fun(code: integer)
function M.spawn(bin, opts, on_stdout, on_exit)
  assert(on_stdout ~= nil and on_exit)
  opts = opts or {}

  local stdout = iuv.new_pipe()
  local stderr = iuv.new_pipe()

  opts["stdio"] = { nil, stdout, stderr }

  jelly.debug("spawning %s %s", bin, opts)
  uv.spawn(bin, opts, function(code) on_exit(code) end)

  iuv.read_start(stdout, function(err, data)
    assert(not err, err)
    on_stdout(data)
    if data == nil then stdout:close() end
  end)

  redirect_to_file(stderr)
end

function M.tail_logs() tail(facts.stdout_fpath, "below") end

return M
