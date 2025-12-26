local converter = require("punctconv.converter")

local function test_0()
  local feeds = {
    { [[-- '世界',"你好"!]], [[—— ‘世界’，“你好”！]] },
    { [[-- "''"世界"'''"]], [[—— “‘’”世界“‘’‘”]] },
    { [[-- ...]], [[—— ……]] },
  }
  for _, defn in ipairs(feeds) do
    local input, expected = unpack(defn)
    local conv = converter()
    local got = table.concat(conv(input))
    assert(got == expected, string.format("%s vs. %s", got, expected))
  end
end

local function test_1()
  local feeds = {
    { [[阿加特悲伤的心有]], [[阿加特悲伤的心有]] },
    { [[时这样说:"远离悔恨、痛苦和犯罪,]], [[时这样说：“远离悔恨、痛苦和犯罪，]] },
    { [[带走我吧,马车!载我去吧,快艇!"]], [[带走我吧，马车！载我去吧，快艇！”]] },
  }
  local conv = converter()
  for _, defn in ipairs(feeds) do
    local input, expected = unpack(defn)
    local got = table.concat(conv(input))
    assert(got == expected, string.format("%s vs. %s", got, expected))
  end
end

test_0()
test_1()
