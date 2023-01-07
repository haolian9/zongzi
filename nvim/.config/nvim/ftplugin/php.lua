---@diagnostic disable: undefined-global
require("ftctx")(function()
  bo.comments = [[s1:/*,mb:*,ex:*/,://,:#]]
  bo.commentstring = [[// %s]]
  bo.suffixesadd = ".php"

  -- php namespace, not fully support psr-0, psr-4
  --setl includeexpr=substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g')
  -- `yii => yii2`
  --bo.includeexpr = [[substitute(substitute(substitute(substitute(v:fname,';','','g'),'^\\','',''),'\\','\/','g'),'yii','yii2','')]]
end)
