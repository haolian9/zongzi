local M = {}

M.find_tip_fn = (function()
  ---@param start TSNode
  ---@return TSNode?
  local function find_tip_decl(start)
    ---@type TSNode?
    local node = start
    while node ~= nil do
      if node:type() == "Decl" then return node end
      node = node:parent()
    end
  end

  ---@param start TSNode
  ---@return TSNode?
  return function(start)
    local tip = find_tip_decl(start)
    if tip == nil then return end
    local inner = tip:named_child(0)
    if inner ~= nil and inner:type() == "FnProto" then return tip end
  end
end)()

M.find_parent_call = (function()
  ---@param start TSNode
  local function find_inner_fn(start)
    ---@type TSNode?
    local node = start
    while node ~= nil do
      if node:type() == "FieldOrFnCall" then return node end
      node = node:parent()
    end
  end

  ---@param start TSNode
  local function try_routes(start)
    local itype = start:type()
    if itype == "IDENTIFIER" then
      -- x.>>y<<.z
      do
        local node = start:parent()
        if node ~= nil and node:type() == "FieldOrFnCall" then return node end
      end
      -- >>x<<.y.z()
      do
        local node = start:next_sibling()
        if node ~= nil and node:type() == "FieldOrFnCall" then return node end
      end
    elseif itype == "FnCallArguments" then
      local node = start:parent()
      if node ~= nil and node:type() == "FieldOrFnCall" then return node end
    end
  end

  ---@param start TSNode
  ---@return TSNode?
  return function(start)
    local inner = find_inner_fn(start) or try_routes(start)
    if inner == nil then return end
    local wrapper = inner:parent()
    assert(wrapper ~= nil and wrapper:type() == "SuffixExpr")
    return wrapper
  end
end)()

do
  ---@param find_parent fun(start: TSNode) TSNode?
  ---@param prev_or_next "next_named_sibling"|"prev_named_sibling"
  local function find_tip_sibling_fn(find_parent, prev_or_next)
    ---@param start TSNode
    ---@return TSNode?
    return function(start)
      local tip = find_parent(start)
      if tip == nil then return end
      ---@type TSNode?
      local node = tip[prev_or_next](tip)
      while node ~= nil do
        if node:type() == "TopLevelDecl" then
          local inner = assert(node:named_child(0))
          if inner:type() == "FnProto" then return node end
        end
        node = node[prev_or_next](node)
      end
    end
  end

  M.find_next_tip_sibling_fn = find_tip_sibling_fn(M.find_tip_fn, "next_named_sibling")
  M.find_prev_tip_sibling_fn = find_tip_sibling_fn(M.find_tip_fn, "prev_named_sibling")
end

return M
