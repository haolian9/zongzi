---@class infra.cmds.SpellFlag
---@field type infra.cmds.SpellVtype
---@field required boolean
---@field default? any|fun(): any
---@field complete? infra.cmds.CompFn

---@alias infra.cmds.SpellVtype 'string'|'number'|'string[]'|'number[]'|'boolean'|'true'

---@class infra.cmds.SpellArg
---@field name string
---@field type infra.cmds.SpellVtype
---@field required boolean
---@field default? any|fun(): any
---@field complete? infra.cmds.CompFn

---@alias infra.cmds.SpellDefault (fun(): any)|string|integer|boolean

---@class infra.cmds.Spell
---@field name   string
---@field action fun(args: infra.cmds.ParsedArgs, ctx: infra.cmds.Args)
---@field flags  {[string]: infra.cmds.SpellFlag}
---@field arg?   infra.cmds.SpellArg
---@field attrs  {range?: true}
local Spell = {}
Spell.__index = Spell

---@param attr 'range'
function Spell:enable(attr) self.attrs[attr] = true end

---@param name      string
---@param type      infra.cmds.SpellVtype
---@param required  boolean
---@param default?  infra.cmds.SpellDefault
---@param complete? infra.cmds.CompFn
function Spell:add_flag(name, type, required, default, complete)
  assert(not (self.arg and self.arg.name == name), "this name has been taken by the arg")
  assert(self.flags[name] == nil, "this name has been taken by a flag")

  self.flags[name] = { default = default, type = type, required = required, complete = complete }
end

---@param name      string
---@param type      infra.cmds.SpellVtype
---@param required  boolean
---@param default?  infra.cmds.SpellDefault
---@param complete? infra.cmds.CompFn
function Spell:add_arg(name, type, required, default, complete)
  assert(self.arg == nil, "re-defining arg")
  assert(self.flags[name] == nil, "this name has been taken by a flag")
  assert(not (required and default ~= nil), "required and default are mutual exclusive")

  self.arg = { name = name, type = type, required = required, default = default, complete = complete }
end

---@param name string
---@param action fun(args: infra.cmds.ParsedArgs, ctx: infra.cmds.Args)
---@return infra.cmds.Spell
return function(name, action) return setmetatable({ name = name, action = action, flags = {}, attrs = {} }, Spell) end
