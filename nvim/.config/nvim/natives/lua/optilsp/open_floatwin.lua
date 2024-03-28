local origins = require("optilsp.origins")

--i dont need fancy highlights
return function(contents, syntax, opts)
  syntax = nil
  opts = opts or {}
  opts.stylize_markdown = false
  opts.border = "none"
  return origins.open_floatwin(contents, syntax, opts)
end
