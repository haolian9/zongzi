local M = {}

---@param origin table|fun(): table
function M.CurriedAPI(origin)
  local ot = type(origin)

  if ot == "table" then
    return setmetatable({}, {
      __index = function(t, k)
        local v = function(...) return origin[k](origin, ...) end
        t[k] = v
        return v
      end,
    })
  elseif ot == "function" then
    return setmetatable({}, {
      __index = function(t, k)
        local v
        if k == "__origin" then
          v = assert(origin())
        else
          v = function(...) return t.__origin[k](t.__origin, ...) end
        end
        t[k] = v
        return v
      end,
    })
  else
    error(string.format("unreachable: unexpected type=%s", ot))
  end
end

--to delay a require statement when the module is being called
--better to use with `---@module 'mod'`
--
--for:     API.meth(), API()
--not for: API.prop, API.prop.meth()
---@param require_path string
---@param overwrite? fun(mod: any)
function M.Proxied(require_path, overwrite)
  return setmetatable({}, {
    __index = function(t, k)
      return setmetatable({}, {
        __call = function(_, ...)
          local mod = require(require_path)
          if overwrite then overwrite(mod) end
          local meth = assert(mod[k])
          if overwrite == nil then rawset(t, k, meth) end
          return meth(...)
        end,
      })
    end,
    __call = function(_, ...)
      local mod = require(require_path)
      if overwrite then overwrite(mod) end
      return mod(...)
    end,
  })
end

return M
