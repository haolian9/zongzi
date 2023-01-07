---@diagnostic disable: undefined-field

-- ref:
-- * https://luajit.org/ext_ffi_tutorial.html
-- * https://luajit.org/ext_ffi_semantics.html
--
-- CAUTION: gc
--

local M = {}

local ffi = require("ffi")

ffi.cdef([[
// nvim specific

  // kudos to ii14: https://matrix.to/#/!JAfPjWAdLCtgeCAwnS:matrix.org/$1662254787169324naFSw:matrix.org?via=matrix.org&via=libera.chat&via=gitter.im
  unsigned char *get_inserted(void);

  // see memory.c
  void xfree(void * p);
  char *xstrdup(const char *str);

  // see buffer_defs.h
  typedef void *buf_T;
  buf_T *buflist_findnr(int nr);
  int setfname(buf_T *buf, char *ffname, char *sfname, bool message);

  // change.c
  void unchanged(buf_T *buf, int ff, bool always_inc_changedtick);

  // see nvim/memline.c
  char *ml_get_buf(buf_T *buf, int32_t lnum, bool will_change);
  size_t strlen(const char *str);

// sys

  typedef int pid_t;
  pid_t waitpid(pid_t pid, int *wstatus, int options);
]])

local C = ffi.C

---@diagnostic disable-next-line
local FAIL = 0
local OK = 1

---@return string|nil
function M.get_inserted()
  local p = ffi.gc(C.get_inserted(), C.xfree)
  if p == nil then return end
  return ffi.string(p)
end

local WNOHANG = 1

function M.WIFEXITED(wstatus)
  return bit.band(wstatus, 0x7f) == 0
end

function M.WEXITSTATUS(wstatus)
  -- according to /usr/include/bits/waitstatus.h
  return bit.rshift(bit.band(wstatus, 0xff00), 8)
end

function M.waitpid(pid, nohang)
  assert(pid ~= nil)
  if nohang == nil then nohang = false end

  local status = ffi.new("int[1]")
  local waited_pid = C.waitpid(pid, status, nohang and WNOHANG or 0)
  return waited_pid, tonumber(status[0])
end

---@param short_name string|nil
---@return boolean
function M.setfname(bufnr, full_name, short_name)
  assert(bufnr ~= nil and full_name ~= nil)

  local buf_p = C.buflist_findnr(bufnr)
  if buf_p == nil then return false end

  -- NB: use xstrdup rather than ffi.new to prevent memory being collected by gc

  local ffname = C.xstrdup(full_name)

  local sfname
  if short_name ~= nil then sfname = C.xstrdup(short_name) end

  return C.setfname(buf_p, ffname, sfname, true) == OK
end

---@param bufnr number
---@param lnum0b_list table @[]number; 0-based
---@return {[number]: number}
function M.lineslen(bufnr, lnum0b_list)
  assert(bufnr ~= nil and #lnum0b_list > 0)

  local buf_p = C.buflist_findnr(bufnr)
  if buf_p == nil then return {} end

  local lens = {}
  for _, lnum in pairs(lnum0b_list) do
    local line_p = C.ml_get_buf(buf_p, lnum + 1, false)
    lens[lnum] = tonumber(C.strlen(line_p))
  end
  return lens
end

---@param bufnr number
---@param reset_fileformat boolean
---@param always_inc_changedtick boolean
function M.unchanged(bufnr, reset_fileformat, always_inc_changedtick)
  local buf_p = C.buflist_findnr(bufnr)
  if buf_p == nil then return end
  C.unchanged(buf_p, reset_fileformat, always_inc_changedtick)
end

return M
