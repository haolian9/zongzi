(comment) @comment
(hash_bang_line) @comment

(identifier) @variable
(vararg_expression) @constant

(field name: (identifier) @field)
(dot_index_expression field: (identifier) @field)

; keyword
["return" "goto"] @keyword.return
(break_statement) @keyword.return
(function_declaration ["function"] @keyword.function)
(function_definition  ["function"] @keyword.function)
"local" @type.qualifier
["for" "while" "repeat" "until" "in"] @repeat
["if" "else" "elseif" "and" "not" "or"] @conditional
[(false) (true)] @boolean

; operator, punctuation
["+" "-" "*" "/" "%"] @operator
["==" "~=" "<=" ">=" "<" ">"] @operator
["=" ".." "#"] @operator
[";" ":" "," "." "end"] @punctuation.delimiter
["(" ")" "[" "]"] @punctuation.bracket
["do" "then" "end"] @punctuation.bracket
(table_constructor ["{" "}"] @punctuation.bracket)

; function
(parameters (identifier) @parameter)
(function_call name: (identifier) @function.call)
(function_declaration name: (identifier) @function)
(function_call name: (dot_index_expression field: (identifier) @function.call))
(function_declaration name: (dot_index_expression field: (identifier) @function))
(method_index_expression method: (identifier) @method)

((function_call name: (identifier) @keyword.return)
    (#eq? @keyword.return "error")
    (#set! "priority" 101))
((function_call name: (dot_index_expression table: (identifier) @variable field: (identifier) @keyword.return))
  (#any-of? @variable "coroutine" "co")
  (#any-of? @keyword.return "yield" "resume")
  (#set! "priority" 101))
((function_call name: (dot_index_expression table: (identifier) @variable field: (identifier) @keyword.return))
  (#eq? @variable "vim")
  (#eq? @keyword.return "schedule")
  (#set! "priority" 101))
((function_call name: (dot_index_expression table: (identifier) @variable field: (identifier) @keyword.return))
  (#eq? @variable "jelly")
  (#eq? @keyword.return "fatal")
  (#set! "priority" 101))

; literal
;(goto_statement (identifier) @keyword.return)
(label_statement (identifier) @keyword.return)
(number) @number
(string) @string

; builtin
((identifier) @variable.builtin (#eq? @variable.builtin "self"))
(nil) @constant.builtin

; error
(ERROR) @error
