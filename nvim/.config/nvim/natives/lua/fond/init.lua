-- design choice
-- * sourcer -> file
-- * file -> fzf -> stdout (maybe)
-- * no app abstract: {state, source, handler}; it's over complicated, bloating the code base
-- * no hard limit for singleton: in my practice, it's over complicated to use mutexes in the callback-based async codes
-- * always need a tmpfile
--
-- file structures
-- * state: {queries: {sourcer: query}}
-- * fzf: fn(src_fpath, last_query, handler, pending_unlink=false)
-- * sources: sourcer(..., handler) src_fpath
-- * handlers: handler(query, action, choices) void
--
-- formats:
-- * file: [fpath]
--    * git tracked files, git changed files, fd, mru file
-- * buffer position: [{bufname, bufnr, col, line, text}]
--    * rg, git grep
--    * lsp symbol
--    * treesitter tokens
--

local M = {}

local fzf = require("fond.fzf")
local handlers = require("fond.handlers")
local sources = require("fond.sources")
local state = require("fond.state")

local function cachable_provider(srcname)
  ---@type fond.CacheableSource
  local source = assert(sources[srcname])
  ---@type fond.fzf.Handler
  local handler = assert(handlers[srcname])

  ---@param use_cached_source ?boolean
  ---@param use_last_query ?boolean
  return function(use_cached_source, use_last_query)
    if use_cached_source == nil then use_cached_source = true end
    if use_last_query == nil then use_last_query = true end
    local last_query = use_last_query and state.queries[srcname] or nil

    source(use_cached_source, function(src_fpath, fzf_opts)
      vim.schedule(function() fzf(src_fpath, last_query, handler, fzf_opts) end)
    end)
  end
end

local function fresh_provider(srcname)
  ---@type fond.Source
  local source = assert(sources[srcname])
  local handler = assert(handlers[srcname])

  return function()
    source(function(src_fpath, fzf_opts)
      vim.schedule(function() fzf(src_fpath, nil, handler, fzf_opts) end)
    end)
  end
end

M.files = cachable_provider("files")
M.siblings = cachable_provider("siblings")
M.tracked = cachable_provider("git_files")
M.document_symbols = cachable_provider("lsp_document_symbols")
M.workspace_symbols = cachable_provider("lsp_workspace_symbols")
M.olds = cachable_provider("olds")
M.ctags = cachable_provider("ctags_file")

M.buffers = fresh_provider("buffers")
M.modified = fresh_provider("git_modified_files")
M.statuses = fresh_provider("git_status_files")
M.windows = fresh_provider("windows")

return M
