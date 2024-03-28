local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local api = vim.api

---@param max_height integer
---@param source guwen.Source
---@return integer
local function calc_lines(max_height, source)
  local count = 0
  local function accum(line) count = count + math.ceil(api.nvim_strwidth(line) / source.width) end

  accum(source.title)
  for line in fn.chained(source.metadata, source.contents, source.notes) do
    accum(line)
    if count >= max_height then return max_height end
  end

  return count
end

---@param max_width integer
---@param max_height integer
---@param source guwen.Source
---@return integer @winid
return function(max_width, max_height, source)
  local bufnr
  local height = 0
  do
    bufnr = Ephemeral({ handyclose = true })

    height = calc_lines(max_height, source)

    local start, stop = 0, 0
    local function advance_bounds(n)
      start = stop
      stop = start + n
    end

    advance_bounds(1)
    api.nvim_buf_set_lines(bufnr, start, stop, false, { source.title })

    if #source.metadata > 0 then
      advance_bounds(#source.metadata)
      api.nvim_buf_set_lines(bufnr, start, stop, false, source.metadata)
    end

    advance_bounds(1)
    api.nvim_buf_set_lines(bufnr, start, stop, false, { "" })
    height = height + 1

    advance_bounds(#source.contents)
    api.nvim_buf_set_lines(bufnr, start, stop, false, source.contents)

    if #source.notes > 0 then
      advance_bounds(1)
      api.nvim_buf_set_lines(bufnr, start, stop, false, { "" })
      height = height + 1

      advance_bounds(#source.notes)
      api.nvim_buf_set_lines(bufnr, start, stop, false, source.notes)
    end

    height = math.min(height, max_height)
  end

  local winid
  do
    local winopts = dictlib.merged({ relative = "win", border = "single" }, rifts.geo.editor(source.width, height))
    --canot use rifts.open.fragment here, since it forces relative=editor
    winid = rifts.open.win(bufnr, true, winopts)

    prefer.wo(winid, "wrap", true)
    api.nvim_win_set_hl_ns(winid, rifts.ns)
  end

  return winid
end
