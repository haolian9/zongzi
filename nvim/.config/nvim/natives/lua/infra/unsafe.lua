---@diagnostic disable: undefined-field

-- ref:
-- * https://luajit.org/ext_ffi_tutorial.html
-- * https://luajit.org/ext_ffi_semantics.html
--
-- CAUTION: gc
--

local M = {}

local ffi = require("ffi")

local ni = require("infra.ni")

ffi.cdef([[
// nvim specific

  // nvim/getchar.c
  // kudos to ii14: https://matrix.to/#/!JAfPjWAdLCtgeCAwnS:matrix.org/$1662254787169324naFSw:matrix.org?via=matrix.org&via=libera.chat&via=gitter.im
  unsigned char *get_inserted(void);

  // nvim/memory.c
  void xfree(void * p);
  char *xstrdup(const char *str);

  // nvim/buffer_defs.h
  typedef void *buf_T;
  buf_T *buflist_findnr(int nr);
  int setfname(buf_T *buf, char *ffname, char *sfname, bool message);

  // nvim/change.c
  void unchanged(buf_T *buf, int ff, bool always_inc_changedtick);

  // nvim/memline.c
  char *ml_get_buf(buf_T *buf, int32_t lnum, bool will_change);
  size_t strlen(const char *str);

  // nvim/help.c
  void prepare_help_buffer(void);

  // nvim/cmdhist.c
  typedef void *list_T;
  typedef struct {
    int hisnum;                       // Entry identifier number.
    char *hisstr;                     // Actual entry, separator char after the NUL.
    uint64_t timestamp;               // Time when entry was added.
    list_T *additional_elements; // Additional entries from ShaDa file.
  } histentry_T;
  const void *hist_iter(const void *const iter, const uint8_t history_type, const bool zero, histentry_T *const hist);

  // nvim/eval/window.c
  typedef void *win_T;
  win_T *win_id2wp(int id);
  void set_topline(win_T *win, int32_t lnum);
  // nvim/move.c
  void changed_window_setting(win_T *win);

  // nvim/search.c
  int fuzzy_match_str(const char * const str, const char * const pat);

  typedef struct {
    int32_t lnum;
    int col;
    int coladd;
  } pos_T;
  typedef void *oparg_T;
  pos_T *findmatch(oparg_T *oap, int initc);


// sys

  typedef int pid_t;
  pid_t waitpid(pid_t pid, int *wstatus, int options);

  int isatty(int fd);

]])

local C = ffi.C

local nvim_enum = {
  FAIL = 0,
  OK = 1,
  HIST_CMD = 0,
}

local c_enum = {
  WNOHANG = 1,
}

---@return string|nil
function M.get_inserted()
  local p = ffi.gc(C.get_inserted(), C.xfree)
  if p == nil then return end
  return ffi.string(p)
end

function M.WIFEXITED(wstatus) return bit.band(wstatus, 0x7f) == 0 end

function M.WEXITSTATUS(wstatus)
  -- according to /usr/include/bits/waitstatus.h
  return bit.rshift(bit.band(wstatus, 0xff00), 8)
end

---@param pid number
---@param nohang boolean
---@return number,number @pid,status
function M.waitpid(pid, nohang)
  assert(pid ~= nil)
  if nohang == nil then nohang = false end

  local status = ffi.new("int[1]")
  local waited_pid = C.waitpid(pid, status, nohang and c_enum.WNOHANG or 0)
  return waited_pid, assert(tonumber(status[0]))
end

---@param short_name string|nil
---@return boolean
function M.buf_setfname(bufnr, full_name, short_name)
  assert(bufnr ~= nil and full_name ~= nil)

  local buf_p = C.buflist_findnr(bufnr)
  if buf_p == nil then return false end

  -- NB: use xstrdup rather than ffi.new to prevent memory being collected by gc

  local ffname = C.xstrdup(full_name)

  local sfname
  if short_name ~= nil then sfname = C.xstrdup(short_name) end

  return C.setfname(buf_p, ffname, sfname, true) == nvim_enum.OK
end

do
  ---@param buf_p userdata
  ---@param lnum integer; 0-based
  ---@return integer? @line length
  local function buflinelen(buf_p, lnum)
    --canot use ml_buf_get_len(buf,lnum) as it raises e315 inevitably
    local ptr = C.ml_get_buf(buf_p, lnum + 1, false)
    if ptr == nil then return end

    return assert(tonumber(C.strlen(ptr)))
  end

  ---may raise E315
  ---alternative: fn.col({lnum+1,'$'})-1
  ---@param bufnr integer
  ---@param lnum integer
  ---@return integer?
  function M.linelen(bufnr, lnum)
    assert(bufnr and lnum)

    local bufptr = C.buflist_findnr(bufnr)
    if bufptr == nil then return end

    return buflinelen(bufptr, lnum)
  end

  ---@param bufnr number
  ---@param range fun():number @iterator of 0-based line numbers
  ---@return fun():(integer?,integer?) @iter(lnum,len)
  function M.linelen_iter(bufnr, range)
    assert(bufnr)

    local bufptr = C.buflist_findnr(bufnr)
    if bufptr == nil then
      return function() end
    end

    local done = false

    return function()
      if done then return end

      local lnum = range()
      if lnum == nil then return end

      local len = buflinelen(bufptr, lnum)
      if len ~= nil then return lnum, len end

      done = true
    end
  end
end

do
  ---@param buf_p userdata
  ---@param lnum integer; 0-based
  ---@return ffi.cdata*? @line ptr
  ---@return integer? @line length
  local function buflinelen(buf_p, lnum)
    --canot use ml_buf_get_len(buf,lnum) as it raises e315 inevitably
    local ptr = C.ml_get_buf(buf_p, lnum + 1, false)
    if ptr == nil then return end

    local len = assert(tonumber(C.strlen(ptr)))
    return ptr, len
  end

  ---@param bufnr integer
  ---@param lnum integer
  ---@return ffi.cdata*? line ptr
  ---@return integer? line length
  function M.lineref(bufnr, lnum)
    assert(bufnr and lnum)

    local bufptr = C.buflist_findnr(bufnr)
    if bufptr == nil then return end

    return buflinelen(bufptr, lnum)
  end

  ---@param bufnr number
  ---@param range fun():number @iterator of 0-based line numbers
  ---@return fun(): ffi.cdata*?,integer?
  function M.lineref_iter(bufnr, range)
    assert(bufnr)

    local bufptr = C.buflist_findnr(bufnr)
    if bufptr == nil then
      return function() end
    end

    local done = false

    return function()
      if done then return end

      local lnum = range()
      if lnum == nil then return end

      local lineptr, len = buflinelen(bufptr, lnum)
      if lineptr ~= nil then return lineptr, len end

      done = true
    end
  end
end

---@param bufnr number
---@param reset_fileformat boolean
---@param always_inc_changedtick boolean
function M.buf_unchanged(bufnr, reset_fileformat, always_inc_changedtick)
  local buf_p = C.buflist_findnr(bufnr)
  if buf_p == nil then return end
  C.unchanged(buf_p, reset_fileformat, always_inc_changedtick)
end

---@param bufnr number
function M.prepare_help_buffer(bufnr)
  --no ctx.buf here, as infra.unsafe is much low-level
  ni.buf_call(bufnr, function() C.prepare_help_buffer() end)
end

---@param fd number
---@return boolean
function M.isatty(fd) return C.isatty(fd) == 1 end

---history of inputs in cmdline
---@return fun(): string?
function M.hist_iter()
  local done = false
  local iter = ffi.new("const void *")
  local entry = ffi.new("histentry_T")

  return function()
    if done then return end

    iter = C.hist_iter(iter, nvim_enum.HIST_CMD, false, entry)
    if iter == nil then
      done = true
    else
      assert(entry.hisstr ~= nil)
      return ffi.string(entry.hisstr)
    end
  end
end

---@param winid integer
---@param toplnum integer @0-based, equals winsaveview().topline - 1
function M.win_set_toplnum(winid, toplnum)
  local win_p = assert(C.win_id2wp(winid))
  ---topline is a row, which is 1-based
  C.set_topline(win_p, toplnum + 1)
  C.changed_window_setting(win_p)
end

---fuzzy match "pat" in "str"
---@return integer score @0 when no match
function M.fuzzymatchstr(str, pat)
  local ret = C.fuzzy_match_str(str, pat)
  return assert(tonumber(ret))
end

---@return integer? lnum 0-based
---@return integer? col 0-based
function M.findmatch()
  local pos = C.findmatch(nil, 0)
  if pos == nil then return end
  return pos.lnum - 1, pos.col
end

return M
