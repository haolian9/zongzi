local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local itertools = require("infra.itertools")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

---calculate height with &wrap
---@param max_height integer
---@param source guwen.Source
---@return integer
local function calc_lines(max_height, source)
  local count = 0
  local function accum(line)
    local width = ni.strwidth(line)
    if width == 0 then
      count = count + 1
    else
      count = count + math.ceil(width / source.width)
    end
  end

  accum(source.title)
  for line in itertools.chained(source.metadata, source.contents, source.notes) do
    accum(line)
    if count >= max_height then return max_height end
  end

  return count
end

---@param max_width integer
---@param max_height integer
---@param source guwen.Source
---@return integer winid
---@return integer bufnr
return function(max_width, max_height, source)
  local lines, height, width = {}, 0, 0
  do
    height = calc_lines(max_height, source)
    table.insert(lines, source.title)
    if #source.metadata > 0 then listlib.extend(lines, source.metadata) end
    table.insert(lines, "")
    height = height + 1
    listlib.extend(lines, source.contents)
    if #source.notes > 0 then
      table.insert(lines, "")
      height = height + 1
      listlib.extend(lines, source.notes)
    end
    height = math.min(height, max_height)
    width = math.min(source.width, max_width)
  end

  local bufnr = Ephemeral({ namepat = "guwen://{bufnr}", handyclose = true }, lines)

  local winid = rifts.open.fragment( --
    bufnr,
    true,
    { relative = "editor", border = "single" },
    { height = height, width = width, horizontal = "mid", vertical = "mid" }
  )

  local wo = prefer.win(winid)
  wo.wrap = true
  wo.winfixheight = true
  wo.winfixwidth = true

  return winid, bufnr
end
