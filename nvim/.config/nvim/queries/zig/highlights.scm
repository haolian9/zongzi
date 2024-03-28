[(container_doc_comment) (doc_comment) (line_comment)] @comment

variable: (IDENTIFIER) @variable
variable_type_function: (IDENTIFIER) @variable

parameter: (IDENTIFIER) @parameter

field_member: (IDENTIFIER) @field
field_access: (IDENTIFIER) @field

["const" "var" "comptime" "threadlocal"] @type.qualifier

; function
function_call: (IDENTIFIER) @function.call
function: (IDENTIFIER) @function.call
["defer" "errdefer" "async" "nosuspend" "await" "suspend" "resume" "export" "extern"] @function.macro

field_constant: (IDENTIFIER) @constant

((BUILTINIDENTIFIER) @include (#any-of? @include "@import" "@cImport"))

; literal
(INTEGER) @number
(FLOAT) @float
(CHAR_LITERAL) @character

; literal.string
[(LINESTRING) (STRINGLITERALSINGLE)] @string
(EscapeSequence) @string.escape
(FormatSequence) @string.special

; literal.label
(BreakLabel (IDENTIFIER) @label)
(BlockLabel (IDENTIFIER) @label)

; operator, punctuation
[(CompareOp) (BitwiseOp) (BitShiftOp) (AdditionOp) (AssignOp) (MultiplyOp) (PrefixOp)] @operator
["*" "**" "->" "=>" ".?" ".*" "?"] @operator
[";" "." "," ":"] @punctuation.delimiter
[".." "..."] @punctuation.special
["[" "]" "(" ")" "{" "}"] @punctuation.bracket
[(Payload "|") (PtrPayload "|") (PtrIndexPayload "|")] @punctuation.bracket
exception: "!" @exception

; keyword
["struct" "enum" "union" "error" "packed" "opaque" "test" "pub" "usingnamespace"] @keyword
["or" "and" "orelse"] @keyword.operator
"fn" @keyword.function
["return" "break" "continue" "try" "unreachable"] @keyword.return
["true" "false"] @boolean
["else" "if" "switch"] @conditional
["for" "while"] @repeat
"catch" @exception
["inline" "noinline" "asm" "callconv" "noalias"] @attribute

; builtin
((IDENTIFIER) @variable.builtin (#eq? @variable.builtin "_"))
(BUILTINIDENTIFIER) @function.builtin
["linksection" "align"] @function.builtin
["allowzero" "volatile" "anytype" "anyframe"] @type.builtin
(BuildinTypeExpr) @type.builtin
["undefined" "null"] @constant.builtin

;; assume TitleCase is a type
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
    parameter: (IDENTIFIER)
  ] @type
  (#match? @type "^[A-Z]")
)
;; assume camelCase is a function
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
    parameter: (IDENTIFIER)
  ] @function
  (#match? @function "^[a-z]+[A-Z]+")
)
;; assume all CAPS_1 is a constant
(
  [
    variable_type_function: (IDENTIFIER)
    field_access: (IDENTIFIER)
  ] @constant
  (#match? @constant "^[A-Z][A-Z_0-9]+$")
)

; Error
(ERROR) @error
