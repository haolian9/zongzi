return {
  NodeType = {},
  parse = function(input)
    -- since i never use the snippet feature from a langserver,
    -- and it's used by vim.lsp.util.get_completion_word,
    -- let it return what it gets
    return input
  end,
}
