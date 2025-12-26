local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("squirrel.insert_import.python")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local puff = require("puff")
local facts = require("squirrel.insert_import.facts")
local nuts = require("squirrel.nuts")

local find_anchor
do
  local function find_last_import(root)
    local last
    for i = 0, root:named_child_count() - 1 do
      local node = root:named_child(i)
      local itype = node:type()
      jelly.debug("node type=%s", itype)
      if itype == "import_statement" or itype == "import_from_statement" then
        last = node
      elseif itype == "comment" then
        -- pass
      elseif itype == "expression_statement" then
        --- could be docstring
        if node:child(0):type() ~= "string" then break end
      else
        break
      end
    end
    return last
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
    prompt = "import://python",
    default = "from ",
    icon = "🚀",
    startinsert = "a",
    bufcall = function(bufnr) prefer.bo(bufnr, "filetype", "python") end,
  }, function(line)
    if line == nil or line == "" then return end
    if strlib.startswith(line, "import ") then
      if #line <= #"import " then return end
    elseif strlib.startswith(line, "from ") then
      if #line <= #"from " then return end
    else
      return jelly.warn("not an import statement")
    end

    buflines.append(host_bufnr, anchor:end_(), line)
    jelly.info("'%s'", line)
  end)
end

