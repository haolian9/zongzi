local M = {}

local fs = require("infra.fs")

do
  --transform: /root/lua/guwen/../..
  local root = fs.parent(fs.parent(fs.resolve_plugin_root("guwen")))

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
