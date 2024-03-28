vim = vim or {}

do
  local function _id(v) return v end

  local deepcopy_funcs = {
    table = function(orig, cache)
      if cache[orig] then return cache[orig] end
      local copy = {}

      cache[orig] = copy
      local mt = getmetatable(orig)
      for k, v in pairs(orig) do
        copy[vim.deepcopy(k, cache)] = vim.deepcopy(v, cache)
      end
      return setmetatable(copy, mt)
    end,
    number = _id,
    string = _id,
    ["nil"] = _id,
    boolean = _id,
    ["function"] = _id,
  }

  ---@generic T: table
  ---@param orig T Table to copy
  ---@return T Table of copied keys and (nested) values.
  function vim.deepcopy(orig, cache)
    local f = deepcopy_funcs[type(orig)]
    if f then
      return f(orig, cache or {})
    else
      if type(orig) == "userdata" and orig == vim.NIL then return vim.NIL end
      error("Cannot deepcopy object of type " .. type(orig))
    end
  end
end

---@param a any First value
---@param b any Second value
---@return boolean `true` if values are equals, else `false`
function vim.deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  if type(a) == "table" then
    for k, v in pairs(a) do
      if not vim.deep_equal(v, b[k]) then return false end
    end
    for k, _ in pairs(b) do
      if a[k] == nil then return false end
    end
    return true
  end
  return false
end

do
  local type_names = {
    ["table"] = "table",
    t = "table",
    ["string"] = "string",
    s = "string",
    ["number"] = "number",
    n = "number",
    ["boolean"] = "boolean",
    b = "boolean",
    ["function"] = "function",
    f = "function",
    ["callable"] = "callable",
    c = "callable",
    ["nil"] = "nil",
    ["thread"] = "thread",
    ["userdata"] = "userdata",
  }

  local function _is_type(val, t) return type(val) == t or (t == "callable" and vim.is_callable(val)) end

  ---@private
  local function is_valid(opt)
    if type(opt) ~= "table" then return false, string.format("opt: expected table, got %s", type(opt)) end

    for param_name, spec in pairs(opt) do
      if type(spec) ~= "table" then return false, string.format("opt[%s]: expected table, got %s", param_name, type(spec)) end

      local val = spec[1] -- Argument value
      local types = spec[2] -- Type name, or callable
      local optional = (true == spec[3])

      if type(types) == "string" then types = { types } end

      if vim.is_callable(types) then
        -- Check user-provided validation function
        local valid, optional_message = types(val)
        if not valid then
          local error_message = string.format("%s: expected %s, got %s", param_name, (spec[3] or "?"), tostring(val))
          if optional_message ~= nil then error_message = error_message .. string.format(". Info: %s", optional_message) end

          return false, error_message
        end
      elseif type(types) == "table" then
        local success = false
        for i, t in ipairs(types) do
          local t_name = type_names[t]
          if not t_name then return false, string.format("invalid type name: %s", t) end
          types[i] = t_name

          if (optional and val == nil) or _is_type(val, t_name) then
            success = true
            break
          end
        end
        if not success then return false, string.format("%s: expected %s, got %s", param_name, table.concat(types, "|"), type(val)) end
      else
        return false, string.format("invalid type name: %s", tostring(types))
      end
    end

    return true, nil
  end

  function vim.validate(opt)
    local ok, err_msg = is_valid(opt)
    if not ok then error(err_msg, 2) end
  end
end

--- Returns true if object `f` can be called as a function.
---
---@param f any Any object
---@return boolean `true` if `f` is callable, else `false`
function vim.is_callable(f)
  if type(f) == "function" then return true end
  local m = getmetatable(f)
  if m == nil then return false end
  return type(m.__call) == "function"
end

do -- string operations
  --- @param s string String to split
  --- @param sep string Separator or pattern
  --- @param opts (table|nil) Keyword arguments |kwargs|:
  ---       - plain: (boolean) Use `sep` literally (as in string.find).
  ---       - trimempty: (boolean) Discard empty segments at start and end of the sequence.
  ---@return fun():string|nil (function) Iterator over the split components
  function vim.gsplit(s, sep, opts)
    local plain
    local trimempty = false
    if type(opts) == "boolean" then
      plain = opts -- For backwards compatibility.
    else
      vim.validate({ s = { s, "s" }, sep = { sep, "s" }, opts = { opts, "t", true } })
      opts = opts or {}
      plain, trimempty = opts.plain, opts.trimempty
    end

    local start = 1
    local done = false

    -- For `trimempty`: queue of collected segments, to be emitted at next pass.
    local segs = {}
    local empty_start = true -- Only empty segments seen so far.

    local function _pass(i, j, ...)
      if i then
        assert(j + 1 > start, "Infinite loop detected")
        local seg = s:sub(start, i - 1)
        start = j + 1
        return seg, ...
      else
        done = true
        return s:sub(start)
      end
    end

    return function()
      if trimempty and #segs > 0 then
        -- trimempty: Pop the collected segments.
        return table.remove(segs)
      elseif done or (s == "" and sep == "") then
        return nil
      elseif sep == "" then
        if start == #s then done = true end
        return _pass(start + 1, start)
      end

      local seg = _pass(s:find(sep, start, plain))

      -- Trim empty segments from start/end.
      if trimempty and seg ~= "" then
        empty_start = false
      elseif trimempty and seg == "" then
        while not done and seg == "" do
          table.insert(segs, 1, "")
          seg = _pass(s:find(sep, start, plain))
        end
        if done and seg == "" then
          return nil
        elseif empty_start then
          empty_start = false
          segs = {}
          return seg
        end
        if seg ~= "" then table.insert(segs, 1, seg) end
        return table.remove(segs)
      end

      return seg
    end
  end

  ---@param s string
  ---@param sep string
  ---@param opts (table|nil) Keyword arguments |kwargs| accepted by |vim.gsplit()|
  ---@return string[]
  function vim.split(s, sep, opts)
    local t = {}
    for c in vim.gsplit(s, sep, opts) do
      table.insert(t, c)
    end
    return t
  end

  --- Trim whitespace (Lua pattern "%s") from both sides of a string.
  ---
  ---@param s string
  ---@return string
  function vim.trim(s) return select(1, s:match("^%s*(.*%S)")) or "" end

  --- Escapes magic chars in |lua-patterns|.
  ---
  ---@see https://github.com/rxi/lume
  ---@param s string
  ---@return string
  function vim.pesc(s) return select(1, s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")) end

  ---@param s string
  ---@param prefix string
  ---@return boolean
  function vim.startswith(s, prefix) return s:sub(1, #prefix) == prefix end

  ---@param s string
  ---@param suffix string
  ---@return boolean
  function vim.endswith(s, suffix) return #suffix == 0 or s:sub(-#suffix) == suffix end
end

do --list operations
  ---@generic T
  ---@param list T[] (list) Table
  ---@param start integer|nil Start range of slice
  ---@param finish integer|nil End range of slice
  ---@return T[] (list) Copy of table sliced from start to finish (inclusive)
  function vim.list_slice(list, start, finish)
    local new_list = {}
    for i = start or 1, finish or #list do
      new_list[#new_list + 1] = list[i]
    end
    return new_list
  end

  ---@param t table List-like table
  ---@return table Flattened copy of the given list-like table
  function vim.tbl_flatten(t)
    local result = {}
    local function _tbl_flatten(_t)
      local n = #_t
      for i = 1, n do
        local v = _t[i]
        if type(v) == "table" then
          _tbl_flatten(v)
        elseif v then
          table.insert(result, v)
        end
      end
    end
    _tbl_flatten(t)
    return result
  end

  ---@generic T: table
  ---@param dst T List which will be modified and appended to
  ---@param src table List from which values will be inserted
  ---@param start (integer|nil) Start index on src. Defaults to 1
  ---@param finish (integer|nil) Final index on src. Defaults to `#src`
  ---@return T dst
  function vim.list_extend(dst, src, start, finish)
    for i = start or 1, finish or #src do
      table.insert(dst, src[i])
    end
    return dst
  end

  ---@param t table Table to check
  ---@param value any Value to compare
  ---@return boolean
  function vim.tbl_contains(t, value)
    for _, v in ipairs(t) do
      if v == value then return true end
    end
    return false
  end
end

do --dict operations
  ---@param t table Table
  ---@return boolean `true` if array-like table, else `false`
  function vim.tbl_islist(t)
    if type(t) ~= "table" then return false end
    return t[1] ~= nil
  end

  ---@param t table Table
  ---@return integer Number of non-nil values in table
  function vim.tbl_count(t)
    if vim.tbl_islist(t) then return #t end

    local count = 0
    for _ in pairs(t) do
      count = count + 1
    end
    return count
  end

  ---@param t table List-like table
  ---@return fun(): any,any
  function vim.spairs(t)
    local keys = vim.tbl_keys(t)
    table.sort(keys)

    local i = 0
    return function()
      i = i + 1
      local k = keys[i]
      if k then return k, t[k] end
    end
  end

  ---@param o table Table to index
  ---@param ... string Optional strings (0 or more, variadic) via which to index the table
  ---
  ---@return any Nested value indexed by key (if it exists), else nil
  function vim.tbl_get(o, ...)
    local keys = { ... }
    if #keys == 0 then return end
    for i, k in ipairs(keys) do
      o = o[k]
      if o == nil then return end
      if type(o) ~= "table" and next(keys, i) then return end
    end
    return o
  end

  ---@param o table Table to add the reverse to
  ---@return table o
  function vim.tbl_add_reverse_lookup(o)
    local keys = vim.tbl_keys(o)
    for _, k in ipairs(keys) do
      local v = o[k]
      if o[v] then error(string.format("The reverse lookup found an existing value for %q while processing key %q", tostring(v), tostring(k))) end
      o[v] = k
    end
    return o
  end

  ---@param t table Table to check
  ---@return boolean
  function vim.tbl_isempty(t) return next(t) == nil end

  ---@generic T
  ---@param func fun(value: T): boolean (function) Function
  ---@param t table<any, T> (table) Table
  ---@return T[] (table) Table of filtered values
  function vim.tbl_filter(func, t)
    local rettab = {}
    for _, entry in pairs(t) do
      if func(entry) then table.insert(rettab, entry) end
    end
    return rettab
  end

  ---@generic T
  ---@param func fun(value: T): any (function) Function
  ---@param t table<any, T> (table) Table
  ---@return table Table of transformed values
  function vim.tbl_map(func, t)
    local rettab = {}
    for k, v in pairs(t) do
      rettab[k] = func(v)
    end
    return rettab
  end

  ---@generic T
  ---@param t table<any, T> (table) Table
  ---@return T[] (list) List of values
  function vim.tbl_values(t)
    local values = {}
    for _, v in pairs(t) do
      table.insert(values, v)
    end
    return values
  end

  ---@generic T: table
  ---@param t table<T, any> (table) Table
  ---@return T[] (list) List of keys
  function vim.tbl_keys(t)
    local keys = {}
    for k, _ in pairs(t) do
      table.insert(keys, k)
    end
    return keys
  end

  do
    --- We only merge empty tables or tables that are not a list
    ---@private
    local function can_merge(v) return type(v) == "table" and (vim.tbl_isempty(v) or not vim.tbl_islist(v)) end

    local function tbl_extend(behavior, deep_extend, ...)
      if behavior ~= "error" and behavior ~= "keep" and behavior ~= "force" then error('invalid "behavior": ' .. tostring(behavior)) end

      if select("#", ...) < 2 then error("wrong number of arguments (given " .. tostring(1 + select("#", ...)) .. ", expected at least 3)") end

      local ret = {}
      if vim._empty_dict_mt ~= nil and getmetatable(select(1, ...)) == vim._empty_dict_mt then ret = vim.empty_dict() end

      for i = 1, select("#", ...) do
        local tbl = select(i, ...)
        vim.validate({ ["after the second argument"] = { tbl, "t" } })
        if tbl then
          for k, v in pairs(tbl) do
            if deep_extend and can_merge(v) and can_merge(ret[k]) then
              ret[k] = tbl_extend(behavior, true, ret[k], v)
            elseif behavior ~= "force" and ret[k] ~= nil then
              if behavior == "error" then error("key found in more than one map: " .. k) end -- Else behavior is "keep".
            else
              ret[k] = v
            end
          end
        end
      end
      return ret
    end

    function vim.tbl_extend(behavior, ...) return tbl_extend(behavior, false, ...) end

    function vim.tbl_deep_extend(behavior, ...) return tbl_extend(behavior, true, ...) end
  end

  ---@param create function?(key:any):any @The function called to create a missing value.
  ---@return table
  function vim.defaulttable(create)
    create = create or function(_) return vim.defaulttable() end
    return setmetatable({}, {
      __index = function(tbl, key)
        rawset(tbl, key, create(key))
        return rawget(tbl, key)
      end,
    })
  end
end

return vim
