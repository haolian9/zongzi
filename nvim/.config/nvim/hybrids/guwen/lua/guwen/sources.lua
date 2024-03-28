local facts = require("guwen.facts")

local api = vim.api
local uv = vim.loop

---@class guwen.Source
---@field title string
---@field metadata string[]
---@field contents string[]
---@field notes string[]
---@field width integer

local sources = {}

local jsonload
do
  local max_loadable_size = bit.lshift(1, 20)

  function jsonload(path)
    local file = assert(uv.fs_open(path, "r", tonumber("600", 8)))
    local ok, json = pcall(function()
      local stat = assert(uv.fs_fstat(file))
      assert(stat.size < max_loadable_size)
      local content = uv.fs_read(file, stat.size)
      assert(#content == stat.size)
      return vim.json.decode(content)
    end)
    uv.fs_close(file)
    if not ok then error(json) end
    return json
  end
end

local function center(text, width)
  assert(text ~= nil and width ~= nil)
  local text_width = api.nvim_strwidth(text)
  if text_width >= width then return text end
  local padding = string.rep(" ", math.floor((width - text_width) / 2))
  return padding .. text
end

local function resolve_width(lines, max_width)
  local width = 0
  for _, line in ipairs(lines) do
    local line_width = api.nvim_strwidth(line)
    if line_width > width then width = line_width end
  end
  return math.min(width, max_width)
end

---@return guwen.Source
sources["楚辞"] = function(max_width)
  local record
  do
    local list = jsonload(facts.fs["楚辞"])
    local poetry_no = math.random(#list)
    record = list[poetry_no]
  end

  local contents = record.content
  local width = resolve_width(contents, max_width)
  local title = center(string.format("%s・%s", record.title, record.section), width)
  local metadata = { center(record.author, width) }

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

---@return guwen.Source
sources["宋词三百首"] = function(max_width)
  local record
  do
    local list = jsonload(facts.fs["宋词三百首"])
    local poetry_no = math.random(#list)
    record = list[poetry_no]
  end

  local contents = record.paragraphs
  local width = resolve_width(contents, max_width)
  local title = center(record.rhythmic, width)
  local metadata = { center(string.format("【%s】%s", "宋", record.author), width) }

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

---@return guwen.Source
sources["唐诗三百首"] = function(max_width)
  local record
  do
    local grouped = jsonload(facts.fs["唐诗三百首"]).content
    local group = grouped[math.random(#grouped)]
    record = group.content[math.random(#group.content)]
  end

  local contents = record.paragraphs
  local width = resolve_width(contents, max_width)
  local title = center(record.chapter, width)
  local metadata = {}
  do
    table.insert(metadata, center(string.format("【%s】%s", "唐", record.author), width))
    if record.subchapter ~= vim.NIL then table.insert(metadata, center(record.subchapter, width)) end
  end

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

---@return guwen.Source
sources["古文观止"] = function(max_width)
  local record
  do
    local path = facts.fs["古文观止"]
    local list = jsonload(path).content
    local volume = list[math.random(#list)]
    record = volume.content[math.random(#volume.content)]
  end

  local contents = record.paragraphs
  local width = resolve_width(contents, max_width)
  local title = center(record.chapter, width)
  local metadata = {}
  do
    table.insert(metadata, center(string.format("%s", record.author), width))
    table.insert(metadata, center(record.source, width))
  end

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

---@return guwen.Source
sources["诗经"] = function(max_width)
  local record
  do
    local list = jsonload(facts.fs["诗经"])
    record = list[math.random(#list)]
  end

  local contents = record.content
  local width = resolve_width(contents, max_width)
  local title = center(record.title, width)
  local metadata = {}
  do
    table.insert(metadata, center(string.format("%s・%s", record.chapter, record.section), width))
  end

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

---@return guwen.Source
sources["论语"] = function(max_width)
  local record
  do
    local list = jsonload(facts.fs["论语"])
    record = list[math.random(#list)]
  end

  local contents = record.paragraphs
  local width = resolve_width(contents, max_width)
  local title = center(record.chapter, width)
  local metadata = {}

  return { title = title, metadata = metadata, contents = contents, notes = {}, width = width }
end

return sources
