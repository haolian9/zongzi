local dictlib = require("infra.dictlib")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("optilsp.hdr_sign")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local open_floatwin = require("optilsp.monkeypatch.open_floatwin")

local log = logging.newlogger("optilsp.hdr_sign", "info")

---@param lines string[]|fun():string?
---@return string[]
local function trim_inline_ln(lines)
  return its(lines) --
    :map(function(el)
      if not strlib.find(el, "\n") then return el end
      local result = el
      result = string.gsub(result, "\n +", " ")
      result = string.gsub(result, "\n", "")
      return result
    end)
    :tolist()
end

---@param result? optilsp.SignResult
---@return string[]|nil
local function to_plains(result)
  if result == nil then return end
  if #result == 1 then return trim_inline_ln(result) end

  local set = {}
  for _, sign in ipairs(result.signatures or {}) do
    ---@diagnostic disable: undefined-field
    assert(sign.label ~= nil)
    set[sign.label] = true
  end

  return trim_inline_ln(dictlib.iter_keys(set))
end

return function(_, result, ctx, opts)
  opts = opts or {}
  opts.focus_id = ctx.method
  opts.close_events = { "InsertLeave" }

  log.debug("sign result: %s", result)
  local plains = to_plains(result)
  log.debug("sign plains: %s", plains)
  if plains == nil then return jelly.info("No information available") end

  return open_floatwin(plains, nil, opts)
end
