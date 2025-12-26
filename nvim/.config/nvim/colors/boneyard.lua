--design: less color, more concentrated
--
--severities:
--* trace: comment, string literal, punctuation
--* debug: if, try...catch, for, const/var, switch/match
--* info: identifier/func/variable
--* warning: async/await, defer
--* error: return, try
--
--
--           HERE LIES
--          SQUIDWARD'S
--             HOPES
--              AND
--            DREAMS
--
--

local ex = require("infra.ex")
local hi = require("infra.highlighter")(0)

-- stylua: ignore
do --main
  do -- prelude
    assert(vim.go.background == "dark")
    ex("highlight", "clear")
    vim.g.colors_name = "boneyard"
  end

  do --vim relevant
    hi("Folded",       { fg = 243 })
    hi("FoldColumn",   { fg = 243, bold = true })
    hi("SignColumn",   {})
    hi("Visual",       { fg = 7, bg = 2 })
    hi("VisualNOS",    { bg = 2 })
    hi("StatusLine",   { fg = 166, bold = true })
    hi("StatusLineNC", { bold = true })
    hi("WinsEparator", { fg = 7 })

    hi("IncSearch",    { fg = 15, bg = 178, bold = true })
    hi("Search",       { fg = 15, bg = 3 })

    hi("WildMenu",     { bg = 222 })

    hi("PMenu",        { fg = 7, bg = 8 })
    hi("PMenuSel",     { fg = 7, bg = 30, bold = true })
    hi("PMenuSbar",    { fg = 8, bg = 7 })
    hi("PMenuThumb",   { fg = 7, bg = 8 })

    hi("NormalFloat",  { fg = 7, bg = 8 })

    hi("CursorColumn", {})
    hi("CursorLine",   { bold = true })

    hi("TabLine",      { fg = 248 })
    hi("TabLineSel",   { fg = 130, bold = true })
    hi("TabLineFill",  {})

    hi("LineNr",       { fg = 10 })
    hi("CursorLineNr", { bold = true })

    --misc
    hi("Whitespace",   { fg = 15 })
    hi("MatchParen",   { fg = 15, bg = 14 })
    hi("MsgSeparator", { fg = 9, bg = 15, underline = true })
  end

  do --diff
    hi("diffAdded",   { fg = 7 })
    hi("diffRemoved", { fg = 243 })
    hi("diffChanged", { fg = 5 })
    hi("diffFile",    { fg = 250 })
    hi("gitDiff",     { fg = 243 })
  end

  do --statusline
    hi("StlDirty",   { fg = 7,  bold = true })
    hi("StlFile",    { fg = 130 })
    hi("StlAltFile", { fg = 248 })
    hi("StlCursor",  { fg = 7   })
    hi("StlSpan",    { fg = 15  })
    hi("StlRepeat",  { fg = 7   })
    hi("StlErrors",  { fg = 1,  bold = true })
  end

  do --general grammar token
    --:h group-name

    --rest: Underlined, Ignore,   Error
    hi("Normal",        { fg = 15 })
    hi("Comment",       { fg = 244 })
    hi("Todo",          { fg = 9, bold = true })

    --any constant
    --rest: Character Number Boolean Float
    hi("Constant",      { fg = 7 })
    hi("String",        { fg = 248 })

    --any variable name
    hi("Identifier",    { fg = 7 })
    hi("Function",      { fg = 7 })

    --any statement
    --rest: Operator Keyword Conditional Repeat Label Exception
    hi("Statement",     { fg = 248 })

    --generic Preprocessor
    --rest: Include Define Macro PreCondit
    hi("PreProc",       { fg = 7 })

    --int,              long,     char,    etc; struct, union, enum, etc.
    --rest: Structure Typedef StorageClass
    hi("Type",          { fg = 7 })

    --any special symbol
    --rest: SpecialChar Tag SpecialComment Debug
    hi("Special",       { fg = 7 })
    hi("Delimiter",     { fg = 248 })
  end

  do --lsp
    hi("@error",                 { fg = 7 })

    hi("@function",              { fg = 7 })
    hi("@variable",              { fg = 7 })
    hi("@function.builtin",      { fg = 7 })
    hi("@type.builtin",          { fg = 7 })
    hi("@variable.builtin",      { fg = 7 })
    hi("@constant.builtin",      { fg = 7 })

    hi("@keyword",               { fg = 31 })
    hi("@keyword.function",      { fg = 31 })
    hi("@function.macro",        { fg = 31 })

    hi("@keyword.return",        { fg = 166 })

    hi("@boolean",               { fg = 248 })
    hi("@repeat",                { fg = 248 })
    hi("@conditional",           { fg = 248 })
    hi("@keyword.operator",      { fg = 248 })
    hi("@exception",             { fg = 248 })
    hi("@type.qualifier",        { fg = 248 })
    hi("@string.escape",         { fg = 248 })
    hi("@string.special",        { fg = 248 })
    hi("@punctuation.delimiter", { fg = 248 })
    hi("@punctuation.special",   { fg = 248 })
    hi("@punctuation.bracket",   { fg = 248 })
    hi("@punctuation.bracket",   { fg = 248 })
  end

  do --diagnostic
    hi("DiagnosticHint", { fg = 10 })
  end

  do --lsp.inlay_hint
    hi('LspInlayHint', { fg = 244 })
  end

  do --git
    hi("gitHash",  { fg = 31 })
    hi("gitEmail", { fg = 250 })
    hi("gitDate",  { fg = 250 })
  end

  do --quickfix
    hi("qfName", { fg = 244 })
    hi("qfBar",  { fg = 244 })
    hi("qfRow",  { fg = 244 })
  end

  do --jelly
    hi("JellySource", { bold = true })
    hi("JellyDebug",  { fg = 244 })
    hi("JellyInfo",   { fg = 15 })
    hi("JellyWarn",   { fg = 9, bold = true })
    hi("JellyError",  { fg = 9, bold = true })
  end
end
