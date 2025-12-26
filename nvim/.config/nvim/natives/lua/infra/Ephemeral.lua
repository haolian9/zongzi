local buflines = require("infra.buflines")
local bufrename = require("infra.bufrename")
local handyclosekeys = require("infra.handyclosekeys")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

---to create ephemeral buffers with mandatory buffer-options

---@class infra.ephemerals.CreateOptions
---@field undolevels? integer @nil=-1
---@field bufhidden? string @nil="wipe"
---@field modifiable? boolean @nil=true
---@field buftype? string @nil="nofile"
---@field name? string
---@field namefn? fun(bufnr: integer):string
---@field namepat? string @{bufnr}
---@field handyclose? boolean

local resolve_opts
do
  local defaults = {
    undolevels = -1,
    bufhidden = "wipe",
    modifiable = true,
    buftype = "nofile",
    handyclose = false,
  }

  ---@param specified? infra.ephemerals.CreateOptions
  ---@return infra.ephemerals.CreateOptions
  function resolve_opts(specified)
    ---@diagnostic disable: param-type-mismatch
    if specified and next(specified) ~= nil then
      return setmetatable(specified, { __index = defaults })
    else
      return defaults
    end
  end
end

---defaults
---* buflisted=false
---* buftype=nofile
---* swapfile=off
---* modeline=off
---* undolevels=-1
---* bufhidden=wipe
---* modifiable=true @but with lines, it'd be false
---
---NB: there are operations always change the bufname, from what i know, termopen does,
---so in these cases, opts.bufname should not be used here
---
---@param opts? infra.ephemerals.CreateOptions
---@param lines? (string|string[])[]
---@return integer
return function(opts, lines)
  opts = opts or {}
  -- lines={}
  if lines ~= nil and opts.modifiable == nil then opts.modifiable = false end
  --order matters, as we access .modifiabe above
  opts = resolve_opts(opts)

  local bufnr = ni.create_buf(false, true)
  local bo = prefer.buf(bufnr)

  ---intented to use no pairs(opts) here, to keep things obvious

  bo.bufhidden = opts.bufhidden
  bo.buftype = opts.buftype

  do
    if lines ~= nil and #lines > 0 then --avoid being recorded by the undo history
      bo.undolevels = -1
      local offset = 0
      ---@diagnostic disable-next-line: param-type-mismatch
      for _, line in ipairs(lines) do
        local lntype = type(line)
        if lntype == "string" then
          buflines.replace(bufnr, offset, line)
          offset = offset + 1
        elseif lntype == "table" then
          buflines.replaces(bufnr, offset, offset + #lines, line)
          offset = offset + #line
        else
          error("unreachable: unknown line type: " .. lntype)
        end
      end
    end

    bo.undolevels = opts.undolevels
    bo.modifiable = opts.modifiable
  end

  do
    local name = (function()
      if opts.name then return opts.name end
      if opts.namefn then return opts.namefn(bufnr) end
      if opts.namepat then return select(1, string.gsub(opts.namepat, "{bufnr}", bufnr)) end
    end)()
    if name then bufrename(bufnr, name) end
  end

  if opts.handyclose then handyclosekeys(bufnr) end

  return bufnr
end
