---@meta

---based on lsp spec 3.16

local M = {}

---@class optilsp.CompleteEvent
---@field completed_item optilsp.CompItem
---@field height         integer
---@field width          integer
---@field row            integer
---@field col            integer
---@field size           integer
---@field scrollbar      1|0

do
  ---@class optilsp.Range
  ---@field start {character: integer, line: integer}
  ---@field end {character: integer, line: integer}}

  ---@class optilsp.TextEdit
  ---@field newText string
  ---@field range   optilsp.Range

  ---@class optilsp.InsertReplaceEdit
  ---@field newText string
  ---@field insert  optilsp.Range
  ---@field replace optilsp.Range

  ---@class optilsp.CompItemTag

  ---@class optilsp.MarkupContent
  ---@field kind  'plaintext'|'markdown'
  ---@field value string

  ---@class optilsp.Command
  ---@field title     string
  ---@field command   string
  ---@field arguments any[]

  ---@class optilsp.CompItem
  ---
  ---The label of this completion item. By default
  ---also the text that is inserted when selecting
  ---this completion.
  ---@field label string
  ---
  ---optilsp.typing.literalCompItemKind()
  ---The kind of this completion item. Based of the kind
  ---an icon is chosen by the editor. The standardized set
  ---of available values is defined in `CompletionItemKind`.
  ---@field kind? integer
  ---
  ---Tags for this completion item.
  ---@since 3.15.0
  ---@field tags? optilsp.CompItemTag[]
  ---
  ---A human-readable string with additional information
  ---about this item, like type or symbol information.
  ---@field detail? string
  ---
  ---A human-readable string that represents a doc-comment.
  ---@field documentation? string|optilsp.MarkupContent
  ---
  ---Indicates if this item is deprecated.
  ---
  ---@deprecated Use `tags` instead if supported.
  ---@field deprecated? boolean
  ---
  ---Select this item when showing.
  ---
  ---*Note* that only one completion item can be selected and that the
  ---tool / client decides which item that is. The rule is that the *first*
  ---item of those that match best is selected.
  ---@field preselect? boolean
  ---
  ---A string that should be used when comparing this item
  ---with other items. When `falsy` the label is used
  ---as the sort text for this item.
  ---@field sortText? string
  ---
  ---A string that should be used when filtering a set of
  ---completion items. When `falsy` the label is used as the
  ---filter text for this item.
  ---@field filterText? string
  ---
  ---A string that should be inserted into a document when selecting
  ---this completion. When `falsy` the label is used as the insert text
  ---for this item.
  ---
  ---The `insertText` is subject to interpretation by the client side.
  ---Some tools might not take the string literally. For example
  ---VS Code when code complete is requested in this example
  ---`con<cursor position>` and a completion item with an `insertText` of
  ---`console` is provided it will only insert `sole`. Therefore it is
  ---recommended to use `textEdit` instead since it avoids additional client
  ---side interpretation.
  ---@field insertText? string
  ---
  ---optilsp.typing.literalInsertTextFormat()
  ---The format of the insert text. The format applies to both the
  ---`insertText` property and the `newText` property of a provided
  ---`textEdit`. If omitted defaults to `InsertTextFormat.PlainText`.
  ---@field insertTextFormat? integer
  ---
  ---optilsp.typing.literalInsertTextMode()
  ---How whitespace and indentation is handled during completion
  ---item insertion. If not provided the client's default value is used.
  ---
  ---@since 3.16.0
  ---@field insertTextMode? integer
  ---
  ---An edit which is applied to a document when selecting this completion.
  ---When an edit is provided the value of `insertText` is ignored.
  ---
  ---*Note:* The range of the edit must be a single line range and it must
  ---contain the position at which completion has been requested.
  ---
  ---Most editors support two different operations when accepting a completion
  ---item. One is to insert a completion text and the other is to replace an
  ---existing text with a completion text. Since this can usually not be
  ---predetermined by a server it can report both ranges. Clients need to
  ---signal support for `InsertReplaceEdit`s via the
  ---`textDocument.completion.insertReplaceSupport` client capability
  ---property.
  ---
  ---*Note 1:* The text edit's range as well as both ranges from an insert
  ---replace edit must be a [single line] and they must contain the position
  ---at which completion has been requested.
  ---*Note 2:* If an `InsertReplaceEdit` is returned the edit's insert range
  ---must be a prefix of the edit's replace range, that means it must be
  ---contained and starting at the same position.
  ---
  ---@since 3.16.0 additional type `InsertReplaceEdit`
  ---@field textEdit? optilsp.TextEdit | optilsp.InsertReplaceEdit
  ---
  ---An optional array of additional text edits that are applied when
  ---selecting this completion. Edits must not overlap (including the same
  ---insert position) with the main edit nor with themselves.
  ---
  ---Additional text edits should be used to change text unrelated to the
  ---current cursor position (for example adding an import statement at the
  ---top of the file if the completion item will insert an unqualified type).
  ---@field additionalTextEdits? optilsp.TextEdit[]
  ---
  ---An optional set of characters that when pressed while this completion is
  ---active will accept it first and then type that character. *Note* that all
  ---commit characters should have `length=1` and that superfluous characters
  ---will be ignored.
  ---@field commitCharacters? string[]
  ---
  ---An optional command that is executed *after* inserting this completion.
  ---*Note* that additional modifications to the current document should be
  ---described with the additionalTextEdits-property.
  ---@field command? optilsp.Command
  ---
  ---A data entry field that is preserved on a completion item between
  ---a completion and a completion resolve request.
  ---@field data? any

  ---@param int integer
  ---@return 'Class'|'Color'|'Constant'|'Constructor'|'Enum'|'EnumMember'|'Event'|'Field'|'File'|'Folder'|'Function'|'Interface'|'Keyword'|'Method'|'Module'|'Operator'|'Property'|'Reference'|'Snippet'|'Struct'|'Text'|'TypeParameter'|'Unit'|'Value'|'Variable'
  function M.literalCompItemKind(int) return assert(vim.lsp.protocol.CompletionItemKind[int]) end

  ---@param int integer
  ---@return 'PlainText'|'Snippet'
  function M.literalInsertTextFormat(int) return assert(vim.lsp.protocol.InsertTextFormat[int]) end

  ---@param int integer
  ---@return 'asIs'|'adjustIndentation'
  function M.literalInsertTextMode(int)
    if int == 1 then return "asIs" end
    if int == 2 then return "adjustIndentation" end
    error("unreachable")
  end
end

do
  ---@class optilsp.GotoDefinition
  local Definition = {
    -- variant 1: lua-langserver
    originSelectionRange = { ["end"] = { character = 1, line = 10 }, start = { character = 0, line = 10 } },
    targetRange = { ["end"] = { character = 16, line = 8 }, start = { character = 15, line = 8 } },
    targetSelectionRange = { ["end"] = { character = 16, line = 8 }, start = { character = 15, line = 8 } },
    targetUri = "file:///home/haoliang/scratch/hello.lua",
    -- variant 2: zls, clangd
    range = { ["end"] = { character = 15, line = 549 }, start = { character = 11, line = 549 } },
    uri = "file:///usr/include/stdio.h",
  }
end

do
  ---@class optilsp.SignInResult
  local Sign = {
    activeParameter = 0,
    documentation = {
      kind = "markdown",
      value = 'Print to stderr, unbuffered, and silently returning on failure. Intended  \nfor use in "printf debugging." Use `std.log` functions for proper logging.',
    },
    label = "fn print(comptime fmt: []const u8, args: anytype) void",
    parameters = {
      { documentation = { kind = "markdown", value = "" }, label = "comptime fmt: []const u8" },
      { documentation = { kind = "markdown", value = "" }, label = "args: anytype" },
    },
  }
  ---@class optilsp.SignResult
  ---@field signatures optilsp.SignResult[]
  local Result = {
    -- variant 1: zls, lua-langserver
    activeParameter = 0,
    activeSignature = 0,
  }
end

return M
