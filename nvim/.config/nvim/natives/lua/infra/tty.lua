-- direct access to neovim's tty

local unsafe = require("infra.unsafe")
local ascii = require("infra.ascii")

local ropes = require("string.buffer")

local M = {}

local read_char
do
  local tty
  do
    -- should be blocking reads, no uv.new_tty here
    -- fd/{1,2} should be the same tty fd
    assert(unsafe.isatty(1), "unreachable: stdout of nvim is not a tty")
    local file, err = io.open("/proc/self/fd/1", "rb")
    assert(file ~= nil, err)
    tty = file
  end

  ---@return string,integer
  function read_char()
    local char = tty:read(1)
    assert(char ~= nil, "tty can not be closed")
    local code = string.byte(char)
    return char, code
  end
end

--read n chars from nvim's tty exclusively, blockingly
--* <esc> to cancel; #return == 0
--* <space> to finish early; #return < n
--
--NB: no ware of multibyte esc-seq
--
---@param n number @n > 0
---@return string @#return >= 0
function M.read_chars(n)
  assert(n > 0, "no need to read")

  local rope = ropes.new(n)

  -- keep **blocking the process** until get enough chars
  for char, code in read_char do
    if code >= ascii.exclam and code <= ascii.tilde then
      -- printable
      rope:put(char)
    elseif code == ascii.esc then
      -- cancelled by esc
      rope:reset()
      break
    elseif code == ascii.space or code == ascii.cr then
      -- finished by space, cr
      break
    else
      --ignore other inputs
    end
    if #rope >= n then break end
  end

  return rope:get()
end

---@return string @char
---@return integer @code
function M.read_raw() return read_char() end

return M
