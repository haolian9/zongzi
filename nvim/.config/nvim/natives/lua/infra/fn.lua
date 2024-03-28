local M = {}

local listlib = require("infra.listlib")

---@alias infra.Iterator.Any fun(): any?
---@alias infra.Iterable.Any infra.Iterator.Any|any[]
--
---@alias infra.Iterator.Str fun(): string?
---@alias infra.Iterable.Str infra.Iterator.Str|string[]
--
---@alias infra.Iterator.Int fun(): integer?
---@alias infra.Iterable.Str infra.Iterator.Int|integer[]

-- parts can be empty string
---@param str string
---@param delimiter string
---@param maxsplit number? @specified or infinited
---@param keepend boolean? @specified or false
---@return infra.Iterator.Str
function M.split_iter(str, delimiter, maxsplit, keepend)
  keepend = keepend or false

  local cursor = 1
  local remain_splits = (maxsplit or math.huge) + 1

  return function()
    if remain_splits < 1 then return end

    if remain_splits == 1 then
      remain_splits = 0
      return str:sub(cursor)
    end

    local del_start, del_stop = str:find(delimiter, cursor, true)
    if del_start == nil or del_stop == nil then
      remain_splits = 0
      return str:sub(cursor)
    end

    remain_splits = remain_splits - 1
    local start = cursor
    local stop = del_start - 1
    if keepend then stop = del_stop end
    cursor = del_stop + 1
    return str:sub(start, stop)
  end
end

-- parts can be empty string
---@return string[]
function M.split(str, delimiter, maxsplit, keepend) return M.tolist(M.split_iter(str, delimiter, maxsplit, keepend)) end

---@param iterable infra.Iterable.Str
---@param separator ?string @specified or ""
---@return string
function M.join(iterable, separator)
  separator = separator or ""
  local list
  do
    local iter_type = type(iterable)
    if iter_type == "function" then
      list = M.tolist(iterable)
    elseif iter_type == "table" then
      list = iterable
    else
      error("unexpected type: " .. iter_type)
    end
  end
  return table.concat(list, separator)
end

---@param iterable function|table @iterator or list
---@return infra.Iterator.Any
function M.iter(iterable)
  local iter_type = type(iterable)
  if iter_type == "function" then
    return iterable
  elseif iter_type == "table" then
    return listlib.iter(iterable)
  else
    error("unknown type of iter: " .. iter_type)
  end
end

---@param iterable infra.Iterable.Any
---@param size number
---@return fun(): any[]?
function M.batch(iterable, size)
  local it = M.iter(iterable)
  return function()
    local stash = {}
    for el in it do
      table.insert(stash, el)
      if #stash >= size then break end
    end
    if #stash > 0 then return stash end
  end
end

---@param it infra.Iterator.Any
---@return any[]
function M.tolist(it)
  local list = {}
  for el in it do
    table.insert(list, el)
  end
  return list
end

---@param fn fun(el: any): any
---@param iterable infra.Iterable.Any
---@return infra.Iterator.Any
function M.map(fn, iterable)
  local it = M.iter(iterable)

  return function()
    local el = it()
    if el == nil then return end
    return fn(el)
  end
end

---for iters which return more than one value in each iteration
---@param fn fun(el: any): any
---@param iterable infra.Iterable.Any
---@return infra.Iterator.Any
function M.mapn(fn, iterable)
  local it = M.iter(iterable)

  return function()
    local el = { it() }
    if #el == 0 then return end
    return fn(unpack(el))
  end
end

---@param fn fun(el: any): any
---@param iterable infra.Iterable.Any
function M.walk(fn, iterable)
  local it = M.iter(iterable)
  while true do
    local el = it()
    if #el == 0 then break end
    fn(el)
  end
end

-- zip.length == longest.length
-- due to lua's for treats first nil as terminate of one iterable
---@param a infra.Iterable.Any
---@param b infra.Iterable.Any
---@return fun(): any[]?
function M.zip_longest(a, b)
  local ai = M.iter(a)
  local bi = M.iter(b)
  return function()
    local ae = ai()
    local be = bi()
    if ae == nil and be == nil then return end
    return { ae, be }
  end
end

-- zip.length == shortest.length
---@param a infra.Iterable.Any
---@param b infra.Iterable.Any
---@return fun(): any[]?
function M.zip(a, b)
  local it = M.zip_longest(a, b)
  return function()
    for ziped in it do
      if ziped[1] == nil or ziped[2] == nil then return end
      return ziped
    end
  end
end

---@param a infra.Iterable.Any
---@param b infra.Iterable.Any
---@return boolean
function M.iter_equals(a, b)
  for ziped in M.zip_longest(a, b) do
    if ziped[1] ~= ziped[2] then return false end
  end
  return true
end

do
  local function evaluate(thing)
    if type(thing) == "function" then return thing() end
    return thing
  end

  function M.either(truthy, a, b)
    if evaluate(truthy) then return evaluate(a) end
    return evaluate(b)
  end
end

---equals to `a == nil and a or b`
function M.nilor(a, b)
  if a ~= nil then return a end
  return b
end

---the corrected version of `s == '' and nil or s`
function M.neqor(eql, a, b)
  if a ~= eql then return a end
  return b
end

---@param iterable fun():infra.Iterable.Any
---@return infra.Iterator.Any
function M.iter_chained(iterable)
  local it = nil
  return function()
    while true do
      if it == nil then
        local maybe_it = iterable()
        if maybe_it == nil then return end
        it = M.iter(maybe_it)
      end
      local el = it()
      if el ~= nil then return el end
      it = nil
    end
  end
end

---@param ... infra.Iterable.Any
---@return infra.Iterator.Any
function M.chained(...) return M.iter_chained(M.map(M.iter, { ... })) end

---@param fn fun(el: any): boolean
---@return infra.Iterator.Any
function M.filter(fn, iterable)
  local it = M.iter(iterable)
  return function()
    while true do
      local el = it()
      if el == nil then return end
      if fn(el) then return el end
    end
  end
end

---@param fn fun(...): boolean
---@param iterable infra.Iterable.Any
function M.filtern(fn, iterable)
  local it = M.iter(iterable)
  return function()
    while true do
      local el = { it() }
      if #el == 0 then return end
      if fn(unpack(el)) then return unpack(el) end
    end
  end
end

---@param iterable infra.Iterable.Any
---@param needle any
---@return boolean
function M.contains(iterable, needle)
  for el in M.iter(iterable) do
    if el == needle then return true end
  end
  return false
end

-- when iterable's each step takes time, fastforward would block for a certain time
---@param iterable infra.Iterable.Any
---@param start integer @1-based, inclusive
---@param stop integer @1-based, exclusive
---@return infra.Iterator.Any
function M.slice(iterable, start, stop)
  assert(start > 0 and stop > start)

  local it = M.iter(iterable)

  for _ = 1, start - 1 do
    assert(it())
  end

  local remain = stop - start
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

---forms:
---* (3)
---* (0, 3)
---* (0, 3, 1)
---* (3, 0, -1)
---@param from integer @inclusive
---@param to? integer @exclusive, nil=0
---@param step? integer @nil=1
function M.range(from, to, step)
  assert(step ~= 0)

  if to == nil then
    assert(step == nil)
    from, to, step = 0, from, 1
  end

  if step == nil then step = 1 end

  if step > 0 then --asc
    local cursor = from - step
    return function()
      cursor = cursor + step
      if cursor >= to then return end
      return cursor
    end
  else --desc
    local cursor = from - step
    return function()
      cursor = cursor + step
      if cursor <= to then return end
      return cursor
    end
  end
end

---NB: no order guarantee
---@param iterable infra.Iterable.Any
---@return {[any]: true}
function M.toset(iterable)
  local set = {}
  for k in M.iter(iterable) do
    set[k] = true
  end
  return set
end

---@param iterable infra.Iterator.Int
---@return integer?
function M.max(iterable)
  local val
  for el in M.iter(iterable) do
    if val == nil then val = el end
    if val < el then val = el end
  end
  return val
end

---@param dict Dict
---@return any,any
function M.items(dict)
  local i
  return function()
    local k, v = next(dict, i)
    i = k
    return k, v
  end
end

return M
