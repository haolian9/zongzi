--design: less color, more concentrated
--
--severities:
--* trace: comment, string literal, punctuation
--* debug: if, try...catch, for, const/var, switch/match
--* info: identifier/func/variable
--* warning: async/await, defer
--* error: return, try
--

local ex = require("infra.ex")
local hi = require("infra.highlighter")(0)

-- stylua: ignore
do -- main
  do -- prelude
    assert(vim.go.background == "light")
    ex("highlight", "clear")
    vim.g.colors_name = "doodlebob"
  end

  do --vim relevant
    hi("Folded",       { fg = 243 })
    hi("FoldColumn",   { fg = 243, bold = true })
    hi("SignColumn",   { fg = 8 })
    hi("Visual",       { fg = 8, bg = 222 })
    hi("VisualNOS",    { fg = 8, bg = 222 })
    hi("StatusLine",   { fg = 9, bold = true })
    hi("StatusLineNC", { fg = 8, bold = true })
    hi("WinsEparator", { fg = 7 })

    hi("IncSearch",    { fg = 8, bg = 222, bold = true })
    hi("Search",       { fg = 8, bg = 222 })

    hi("WildMenu",     { fg = 8, bg = 222 })

    hi("PMenu",        { fg = 0, bg = 7 })
    hi("PMenuSel",     { fg = 15, bg = 6, bold = true })
    hi("PMenuSbar",    { fg = 15 })
    hi("PMenuThumb",   { fg = 15, bg = 7 })

    hi("NormalFloat",  { fg = 0, bg = 7 })

    hi("CursorColumn", {})
    hi("CursorLine",   { bold = true })

    hi("TabLine",      { fg = 8 })
    hi("TabLineSel",   { fg = 9, bold = true })
    hi("TabLineFill",  {})

    hi("LineNr",       { fg = "darkgray" })
    hi("CursorLineNr", { fg = 8, bold = true })

    --misc
    hi("Whitespace",   { fg = 15, bg = 8 })
    hi("MatchParen",   { fg = 15, bg = 14 })
    hi("MsgSeparator", { fg = 9, underline = true })
  end

  do --diff
    hi("diffAdded",   { fg = 8 })
    hi("diffRemoved", { fg = 243 })
    hi("diffChanged", { fg = 5 })
    hi("diffFile",    { fg = 0, bold = true })
    hi("gitDiff",     { fg = 0 })
  end

  do --statusline
    hi("StlDirty",   { fg = 8,  bold = true })
    hi("StlFile",    { fg = 9   })
    hi("StlAltFile", { fg = 240 })
    hi("StlCursor",  { fg = 8   })
    hi("StlSpan",    { fg = 15  })
    hi("StlRepeat",  { fg = 8   })
    hi("StlErrors",  { fg = 1,  bold = true })
  end

  do --general grammar token
    --:h group-name

    --rest: Underline Ignore Error
    hi("Normal",     { fg = 8 })
    hi("Comment",    { fg = 241 })
    hi("Todo",       { fg = 9, bold = true })

    --any constant
    --rest: Character Number Boolean Float
    hi("Constant",   { fg = 235 })
    hi("String",     { fg = 240 })

    --any variable name
    hi("Identifier", { fg = 8 })
    hi("Function",   { fg = 8 })

    --any statement
    --rest: Operator Keyword Conditional Repeat Label Exception
    hi("Statement",  { fg = 240 })

    --generic Preprocessor
    --rest: Include Define Macro PreCondit
    hi("PreProc",    { fg = 8 })

    --int,           long, char, etc; struct, union, enum, etc.
    --rest: Structure Typedef StorageClass
    hi("Type",       { fg = 8 })

    --any special symbol
    --rest: SpecialChar Tag SpecialComment Debug
    hi("Special",    { fg = 8 })
    hi("Delimiter",  { fg = 240 })
  end

  do --lsp
    hi("@error",                 { fg = 8 })

    hi("@function",              { fg = 8 })
    hi("@variable",              { fg = 8 })
    hi("@function.builtin",      { fg = 8 })
    hi("@type.builtin",          { fg = 8 })
    hi("@variable.builtin",      { fg = 8 })
    hi("@constant.builtin",      { fg = 8 })

    hi("@keyword",               { fg = 31 })
    hi("@keyword.function",      { fg = 31 })
    hi("@function.macro",        { fg = 31 })

    hi("@keyword.return",        { fg = 124 })

    hi("@conditional",           { fg = 240 })
    hi("@keyword.operator",      { fg = 240 })
    hi("@exception",             { fg = 240 })
    hi("@type.qualifier",        { fg = 240 })
    hi("@string.escape",         { fg = 240 })
    hi("@string.special",        { fg = 240 })
    hi("@punctuation.delimiter", { fg = 240 })
    hi("@punctuation.special",   { fg = 240 })
    hi("@punctuation.bracket",   { fg = 240 })
    hi("@punctuation.bracket",   { fg = 240 })
  end

  do --diagnostic
    hi("DiagnosticHint", { fg = 10 })
  end

  do --lsp.inlay_hint
    hi('LspInlayHint', { fg = 241 })
  end

  do --git
    hi("gitHash",  { fg = 31 })
    hi("gitEmail", { fg = 241 })
    hi("gitDate",  { fg = 241 })
  end

  do --quickfix
    hi("qfName", { fg = 241 })
    hi("qfBar",  { fg = 241 })
    hi("qfRow",  { fg = 241 })
  end

  do --jelly
    hi("JellySource", { bold = true })
    hi("JellyDebug",  { fg = 241 })
    hi("JellyInfo",   { fg = 8 })
    hi("JellyWarn",   { bg = 9, bold = true })
    hi("JellyError",  { bg = 9, bold = true })
  end
end
