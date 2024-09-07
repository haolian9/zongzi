local unsafe = require("infra.unsafe")

---@class infra.builtin_fuzzymatch.Opts
---@field sort? 'asc'|'desc'|false @nil='asc'
---@field tostr? fun(candidate:any): string

local function compare_descent(a, b) return a[2] > b[2] end
local function compare_ascent(a, b) return a[2] < b[2] end

---@param opts? infra.builtin_fuzzymatch.Opts
---@return infra.builtin_fuzzymatch.Opts
local function normalize_opts(opts)
  if opts == nil then opts = {} end
  if opts.sort == nil then opts.sort = "asc" end
  if opts.tostr == nil then opts.tostr = function(str) return str end end
  return opts
end

---@generic T
---@param candidates T[]
---@param token string
---@param opts? infra.builtin_fuzzymatch.Opts
---@return T[]
return function(candidates, token, opts)
  if token == "" then return candidates end

  opts = normalize_opts(opts)

  if opts.sort == false then
    local matches = {}
    for _, cand in ipairs(candidates) do
      local score = unsafe.fuzzymatchstr(opts.tostr(cand), token)
      if score ~= 0 then table.insert(matches, cand) end
    end
    return matches
  end

  local scores = {} ---@type [any, integer][]
  for _, cand in ipairs(candidates) do
    local score = unsafe.fuzzymatchstr(opts.tostr(cand), token)
    if score ~= nil then table.insert(scores, { cand, score }) end
  end
  if #scores == 0 then return {} end

  if opts.sort == "asc" then
    table.sort(scores, compare_ascent)
  elseif opts.sort == "desc" then
    table.sort(scores, compare_descent)
  else
    error("unreachable")
  end

  local matches = {}
  for i, tuple in ipairs(candidates) do
    matches[i] = tuple[1]
  end

  return matches
end
