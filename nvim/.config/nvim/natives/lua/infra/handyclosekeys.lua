local bufmap = require("infra.keymap.buffer")

---@param bufnr integer
return function(bufnr)
  local bm = bufmap.wraps(bufnr)
  for _, lhs in ipairs({ "q", "<esc>", "<c-[>", "<c-]>" }) do
    bm.n(lhs, "<cmd>q<cr>")
  end
end
