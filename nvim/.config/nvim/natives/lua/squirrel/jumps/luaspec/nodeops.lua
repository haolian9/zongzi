local M = {}

local jelly = require("infra.jellyfish")("squirrel.jumps.luaspec")

local nuts = require("squirrel.nuts")

---@type squirrel.nuts.goto_node
function M.goto_node_first_identifier(winid, node)
  ---@type TSNode?
  local target = node
  while target ~= nil do
    if target:type() == "identifier" then break end
    target = target:named_child(0)
  end
  assert(target ~= nil)
  nuts.goto_node_head(winid, target)
end

---@param winid number
---@param node TSNode
---@return boolean
function M.vsel_node_body(winid, node)
  local body
  do
    local node_type = node:type()
    if node_type == "block" then
      body = node
    elseif node_type == "if_statement" or node_type == "elseif_statement" then
      local bodies = node:field("consequence")
      assert(#bodies == 1)
      body = bodies[1]
    else
      -- else_statement, for_statement, function_definition, function_declaration
      -- has a body
      local bodies = node:field("body")
      if #bodies < 1 then
        jelly.info("no body found")
        return false
      end
      body = bodies[1]
    end
  end
  return nuts.vsel_node(winid, body)
end

return M
