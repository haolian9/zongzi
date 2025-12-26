local M = {}

local vsel = require("infra.vsel")

local nuts = require("squirrel.nuts")

---@type squirrel.nuts.goto_node
function M.goto_node_first_identifier(winid, node)
  ---@type TSNode?
  local target = node
  while target ~= nil do
    if target:type() == "IDENTIFIER" then break end
    target = target:named_child(0)
  end
  assert(target ~= nil)
  nuts.goto_node_head(winid, target)
end

---@param winid number
---@param node TSNode
function M.vsel_node_body(winid, node)
  local body
  do
    local ntype = node:type()
    if ntype == "Decl" then
      body = assert(node:named_child(1))
    else
      error("unexpected node: " .. ntype)
    end
  end

  do
    local start, _, stop = body:range()
    start = start + 1 -- exclusive `{`
    stop = stop - 1 + 1 -- exclusive `}`, stop is exclusive
    vsel.select_lines(winid, start, stop)
  end
end

return M
