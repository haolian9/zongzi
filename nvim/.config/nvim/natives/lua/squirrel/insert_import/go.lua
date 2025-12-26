local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("squirrel.import_import.go")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

local puff = require("puff")
local facts = require("squirrel.insert_import.facts")
local nuts = require("squirrel.nuts")

local find_anchor
do
  local function find_last_import(root)
    local last
    local package_node
    for i = 0, root:named_child_count() - 1 do
      local node = root:named_child(i)
      local itype = node:type()
      jelly.debug("node type=%s", itype)
      if itype == "import_declaration" then
        last = node
      elseif itype == "package_clause" then
        package_node = node
      elseif itype == "comment" then
        -- pass
      else
        break
      end
    end
    -- if there is no import node, then try package_node
    return last or package_node
  end

  ---@param bufnr integer
  ---@return TSNode
  function find_anchor(bufnr)
    local root = assert(nuts.get_root_node(bufnr))

    return find_last_import(root) or facts.origin
  end
end

return function()
  local host_bufnr = ni.get_current_buf()
  local anchor = find_anchor(host_bufnr)

  puff.input({
    prompt = "require",
    default = 'import ""',
    icon = "🚀",
    startinsert = "i",
    bufcall = function(bufnr) prefer.bo(bufnr, "filetype", "go") end,
  }, function(line)
    if line == nil or line == "" then return end
    if #line <= #'import""' then return end

    buflines.append(host_bufnr, anchor:end_(), line)
    jelly.info("'%s'", line)
  end)
end
