-- todo: maybe make use of coroutine? https://www.lua.org/pil/9.3.html

local M = {}

-- parts can be empty string
---@param str string
---@param del string
---@param maxsplit ?number @specified or infinited
---@param keepends ?boolean @specified or false
---@return function @iterator
function M.split_iter(str, del, maxsplit, keepends)
  keepends = keepends or false

  -- todo: no use of string:find
  local pattern = del
  if del == "." then
    pattern = "%."
  elseif del == "%" then
    pattern = "%%"
  end

  local finished = false
  local cursor = 1
  local remain = (maxsplit or math.huge) + 1

  return function()
    if finished then return end

    if remain == 1 then
      finished = true
      return str:sub(cursor)
    end

    local del_start, del_stop = str:find(pattern, cursor)
    if del_start == nil then
      finished = true
      return str:sub(cursor)
    end

    remain = remain - 1
    local start = cursor
    local stop = del_start - 1
    if keepends then stop = del_stop end
    cursor = del_stop + 1
    return str:sub(start, stop)
  end
end

-- parts can be empty string
---@return table @list
function M.split(str, del, maxsplit, keepends)
  -- todo: vim.split
  return M.concrete(M.split_iter(str, del, maxsplit, keepends))
end

---@param iterable function|table @iterator of strings
---@param del ?string @specified or ""
---@return string
function M.join(iterable, del)
  local list
  local _type = type(iterable)
  if _type == "function" then
    list = M.concrete(iterable)
  elseif _type == "table" then
    list = iterable
  else
    error("unexpected type: " .. _type)
  end
  return table.concat(list, del or "")
end

-- iterate over list.values
---@param list table @list
function M.list_iter(list)
  local cursor = 1
  return function()
    if cursor > #list then return end
    local el = list[cursor]
    cursor = cursor + 1
    return el
  end
end

---@param list table @[tuple]
function M.list_iter_unpacked(list)
  local iter = M.list_iter(list)
  return function()
    local el = iter()
    if el == nil then return end
    return unpack(el)
  end
end

---@param iterable function|table @iterator or list
---@return function @iterable
function M.iterate(iterable)
  local _type = type(iterable)
  if _type == "function" then
    return iterable
  elseif _type == "table" then
    return M.list_iter(iterable)
  else
    error("unknown type of iter: " .. _type)
  end
end

-- inplace extend
---@param a table @list
---@param b table|function @list
function M.list_extend(a, b)
  -- todo: vim.list_extend
  for el in M.iterate(b) do
    table.insert(a, el)
  end
end

---@param iterable function|table @iterable or list
---@param size number
---@return function @iterable
function M.batch(iterable, size)
  local it = M.iterate(iterable)
  return function()
    local stash = {}
    for el in it do
      table.insert(stash, el)
      if #stash >= size then break end
    end
    if #stash > 0 then return stash end
  end
end

---@param it function
---@return table @list
function M.concrete(it)
  local list = {}
  for el in it do
    table.insert(list, el)
  end
  return list
end

---@param fn function
---@param iterable function|table
---@return function @iterable
function M.map(fn, iterable)
  local it = M.iterate(iterable)

  return function()
    local el = { it() }
    if #el == 0 then return end
    return fn(unpack(el))
  end
end

-- zip.length == longest.length
-- due to lua's for treats first nil as terminate of one iterable
-- todo: support varargs
--
---@param a function|table @iterator or list
---@param b function|table @iterator or list
---@return function @iterable -> tuple
function M.zip_longest(a, b)
  local ai = M.iterate(a)
  local bi = M.iterate(b)
  return function()
    local ae = ai()
    local be = bi()
    if ae == nil and be == nil then return end
    return { ae, be }
  end
end

-- zip.length == shortest.length
---@param a function|table @iterator or list
---@param b function|table @iterator or list
---@return function @iterable -> tuple
function M.zip(a, b)
  local it = M.zip_longest(a, b)
  return function()
    for ziped in it do
      if ziped[1] == nil or ziped[2] == nil then return end
      return ziped
    end
  end
end

---@param a function|table @iterator or list
---@param b function|table @iterator or list
---@return boolean
function M.iter_equals(a, b)
  for ziped in M.zip_longest(a, b) do
    if ziped[1] ~= ziped[2] then return false end
  end
  return true
end

function M.either(truthy, a, b)
  local function evaluate(thing)
    if type(thing) == "function" then return thing() end
    return thing
  end

  if truthy then return evaluate(a) end

  return evaluate(b)
end

---@param iterable function @iterable -> iterable
function M.iter_chained(iterable)
  local it = nil
  return function()
    while true do
      if it == nil then
        it = iterable()
        if it == nil then return end
      end
      local el = it()
      if el ~= nil then return el end
      it = nil
    end
  end
end

---@vararg table|function @iterables
function M.chained(...)
  return M.iter_chained(M.map(M.list_iter, { ... }))
end

---@param fn function @(el) bool
function M.filter(fn, iterable)
  -- todo: vim.tbl_filter
  local it = M.iterate(iterable)
  return function()
    while true do
      local el = { it() }
      if #el == 0 then return end
      if fn(unpack(el)) then return unpack(el) end
    end
  end
end

function M.contains(iterable, needle)
  for el in M.iterate(iterable) do
    if el == needle then return true end
  end
  return false
end

-- inclusive start, inclusive stop
function M.slice(iterable, start, stop)
  assert(start > 0 and stop >= start)

  local it = M.iterate(iterable)

  -- todo: what if iterable's each stop takes time, fastforward would block
  -- for a long time
  for _ = 1, start - 1 do
    assert(it())
  end

  local remain = stop + 1 - start
  return function()
    if remain < 1 then return end
    local el = { it() }
    if #el == 0 then
      remain = 0
    else
      remain = remain - 1
    end
    return unpack(el)
  end
end

-- same to python's range: inclusive start, exclusive stop
function M.range(start, stop, step)
  if stop == nil then
    stop = start
    start = 0
  end
  assert(stop >= start)
  step = step or 1
  assert(step > 0)

  local cursor = start - step
  return function()
    cursor = cursor + step
    if stop <= cursor then return end
    return cursor
  end
end

function M.pop(list)
  local len = #list
  if len == 0 then return end
  -- todo table.remove?
  local tail = list[len]
  list[len] = nil
  return tail
end

function M.get(dreams, ...)
  local layer = dreams
  for path in M.list_iter({ ... }) do
    layer = layer[path]
    if layer == nil then return end
  end
  return layer
end

return M
