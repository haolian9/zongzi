local nuls = require("null-ls")
local startswith = vim.startswith

-- from https://ziglang.org/documentation/master/#Builtin-Functions
-- {fn.lower: fn}
local CANDIDATES = nil

-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
-- Text          = 1
-- Method        = 2
-- Function      = 3
-- Constructor   = 4
-- Field         = 5
-- Variable      = 6
-- Class         = 7
-- Interface     = 8
-- Module        = 9
-- Property      = 10
-- Unit          = 11
-- Value         = 12
-- Enum          = 13
-- Keyword       = 14
-- Snippet       = 15
-- Color         = 16
-- File          = 17
-- Reference     = 18
-- Folder        = 19
-- EnumMember    = 20
-- Constant      = 21
-- Struct        = 22
-- Event         = 23
-- Operator      = 24
-- TypeParameter = 25
local Kind = vim.lsp.protocol.CompletionItemKind

local load_candidates = function()
  if CANDIDATES == nil then
    CANDIDATES = {}
    local path = vim.fn.stdpath("config") .. "/dict/zig-fn"
    for line in io.lines(path) do
      CANDIDATES[string.lower(line)] = line
    end
  end
  return CANDIDATES
end

local get_candidates = function(present)
  -- param present: str, user input
  local lower_present = string.lower(present)
  local items = {}
  for lower_candidate, val in pairs(load_candidates()) do
    if startswith(lower_candidate, lower_present) then
      -- TODO@haoliang make the completion case-insensitive
      table.insert(items, {
        label = val,
        kind = Kind["Function"],
      })
    end
  end
  return items
end

local complete = function(params, done)
  -- params for COMPLETION source:
  -- * word_to_complete: str,
  -- * content: []str,
  -- * bufname: str,
  -- * bufnr: int,
  -- * client_id: int
  -- * col: int, row: int,
  -- * ft: str
  -- * lsp_method: str
  -- * method: str; NULL_LS_COMPLETION
  --
  -- done: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionList
  -- * isIncomplete: completion is finished or not
  -- * items: []{label, kind, detail, documentation}

  local present = params.word_to_complete

  if not startswith(present, "@") then
    done({ { items = {}, isIncomplete = false } })
    return
  end

  local items = get_candidates(present)

  done({ { items = items, isIncomplete = false } })
end

return {
  name = "zig-fn",
  method = nuls.methods.COMPLETION,
  filetypes = { "zig" },
  generator = {
    fn = complete,
    async = true,
    copy_params = false,
  },
}
