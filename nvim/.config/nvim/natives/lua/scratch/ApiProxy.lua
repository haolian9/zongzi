--to delay a require statement when the module is being called
--better to use with `---@module 'mod'`
--
--for:     API.meth(), API()
--not for: API.prop, API.prop.meth()
---@param require_path string
---@param overwrite? fun(mod: any)
return function(require_path, overwrite)
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
