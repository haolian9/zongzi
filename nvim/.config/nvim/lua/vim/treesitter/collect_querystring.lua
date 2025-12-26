---to replace treesitter.query.get_files() and read_query_files
---
---EXACT pattern:
---* '; include: {lang}'
---* '; include: {lang},{lang}'

local jelly = require("infra.jellyfish")("treesit.collect_querystring", "info")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

---@param lang string
---@param purpose string
---@param bag table
local function collect(lang, purpose, bag)
  local fpath
  do
    local pattern = string.format("queries/%s/%s.scm", lang, purpose)
    --NB: use 'false' to pick the first one only, so &rtp order matters
    local result = ni.get_runtime_file(pattern, false)
    if #result == 0 then return end
    assert(#result == 1)
    fpath = result[1]
  end

  for line in io.lines(fpath) do
    ---@cast line string
    if line:find("^; include: ") then
      local include = line:sub(#"; include: " + 1, -1)
      for s in strlib.iter_splits(include, ",") do
        s = strlib.strip(s)
        if s ~= "" then
          jelly.debug("'%s' includes '%s'", lang, s)
          collect(s, purpose, bag)
        end
      end
    else
      table.insert(bag, line)
    end
  end
end

--- ';;include {lang}'
---@param ft string
---@param purpose 'highlight'
---@return ''|string
return function(ft, purpose)
  local bag = {}
  collect(ft, purpose, bag)
  return table.concat(bag, "\n")
end

