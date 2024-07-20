---available builtin apis:
---* switch current list: :colder, :cnewer
---* :copen
---* quickfix stack: :chistory
---* QuickfixCmdPost, QuickfixCmdPre
---* :cfile
---
---design choices
---* no stack: setqflist({}, 'f')
---  * because i found no way to remove a member from the stack
---  * i dont care those who cant be converted to use this plugin
---* no ffi call on set_errorlist for benefits on performance and overhead
---  * since there is no way to make the tv_{list,dict} survive from the GC
---* namespace
---* textfunc
--

return {
  quickfix = require("sting.quickfix"),
  location = require("sting.location"),
  rhs = require("sting.rhs"),
  toggle = require("sting.toggle"),
}
