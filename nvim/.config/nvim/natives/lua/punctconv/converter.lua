-- see: https://zh.wikipedia.org/wiki/%E6%A0%87%E7%82%B9%E7%AC%A6%E5%8F%B7

local utf8 = require("infra.utf8")

local conv1 = {
  [","] = "，",
  [";"] = "；",
  ["/"] = "、",
  ["["] = "［",
  ["]"] = "］",
  [":"] = "：",
  ["("] = "（",
  [")"] = "）",
  ["{"] = "｛",
  ["}"] = "｝",
  ["~"] = "～",
  ["*"] = "·",
  ["!"] = "！",
  ["?"] = "？",
}

-- paired
local conv2 = {
  ["'"] = { [[‘]], [[’]] },
  ['"'] = { [[“]], [[”]] },
}

-- precedence by char size
local conv3 = {
  [3] = {
    ["..."] = "……",
  },
  [2] = {
    ["--"] = "——",
  },
  [1] = {
    ["."] = "。",
    ["-"] = "－",
  },
}

local conv3_max = 3

local function conv3_concat(list, first_n)
  if first_n == conv3_max then return table.concat(list) end

  local sub = {}
  for i = 1, first_n do
    sub[i] = list[i]
  end
  return table.concat(sub)
end

---@param original string @utf8 string
---@param state table @internel state acorss multiple convertion, default={}
---@return table
local function convert(original, state)
  assert(state ~= nil)
  local iter = utf8.iterate(original)
  local result = {}

  local buf = { iter() }
  while #buf > 0 do
    do -- conv1
      local rune = buf[1]
      local to = conv1[rune]
      if to ~= nil then
        table.insert(result, to)
        table.remove(buf, 1)
        goto continue
      end
    end

    do -- conv2
      local rune = buf[1]
      local too = conv2[rune]
      if too ~= nil then
        local count = state.conv2_count[rune]
        ---@diagnostic disable-next-line
        state.conv2_count[rune] = count + 1
        local to = too[(count % 2) + 1]
        table.insert(result, to)
        table.remove(buf, 1)
        goto continue
      end
    end

    do -- conv3
      for _ = 1, conv3_max - #buf do
        local next_rune = iter()
        if next_rune == nil then break end
        table.insert(buf, next_rune)
      end
      local ate = 0
      for i = #buf, 1, -1 do
        local a = conv3_concat(buf, i)
        local to = conv3[i][a]
        if to ~= nil then
          table.insert(result, to)
          ate = i
          goto continue
        end
      end
      for _ = 1, ate do
        table.remove(buf, 1)
      end
    end

    do
      table.insert(result, buf[1])
      table.remove(buf, 1)
      goto continue
    end

    do
      local rune = iter()
      if rune ~= nil then table.insert(buf, rune) end
    end

    ::continue::
  end

  return result
end

local function make_state()
  local state = {}
  if state.conv2_count == nil then state.conv2_count = {} end
  for a, _ in pairs(conv2) do
    state.conv2_count[a] = 0
  end
  return state
end

return function()
  local state = make_state()
  return function(original) return convert(original, state) end
end
