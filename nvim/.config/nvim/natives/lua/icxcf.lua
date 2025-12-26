local augroups = require("infra.augroups")
local feedkeys = require("infra.feedkeys")

local toggle = false

return function()
  --no re-entrance
  if toggle then return end

  toggle = true --<c-x><c-f> should not fail
  feedkeys.keys("<c-x><c-f>", "n") --feedkeys.keys caches

  local aug = augroups.Augroup("icxcf://")

  aug:repeats("TextChangedI", { callback = function() feedkeys.keys("<c-x><c-f>", "n") end })

  aug:repeats("InsertCharPre", {
    callback = function()
      if vim.v.char ~= "/" then return end
      vim.v.char = ""
    end,
  })

  aug:once("InsertLeavePre", {
    callback = function()
      aug:unlink()
      toggle = false
    end,
  })
end
