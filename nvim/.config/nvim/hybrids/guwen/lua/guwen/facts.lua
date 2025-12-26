local M = {}

local fs = require("infra.fs")
local resolve_plugin_root = require("infra.resolve_plugin_root")

do
  local root = resolve_plugin_root("guwen")

  M.fs = {
    ["楚辞"] = fs.joinpath(root, "vendor/chinese-poetry/chuci/chuci.json"),
    ["唐诗三百首"] = fs.joinpath(root, "vendor/chinese-poetry/mengxue/tangshisanbaishou.json"),
    ["宋词三百首"] = fs.joinpath(root, "vendor/chinese-poetry/ci/宋词三百首.json"),
    ["古文观止"] = fs.joinpath(root, "vendor/chinese-poetry/mengxue/guwenguanzhi.json"),
    ["论语"] = fs.joinpath(root, "vendor/chinese-poetry/lunyu/lunyu.json"),
    ["诗经"] = fs.joinpath(root, "vendor/chinese-poetry/shijing/shijing.json"),
  }
end

return M
