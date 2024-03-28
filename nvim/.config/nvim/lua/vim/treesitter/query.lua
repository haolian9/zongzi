--[[
changes:
* localize helpers
* rm deprecated apis
* no explicit_queries, no .set()
* no query-modeline
* .get_files() only recognize the first `highlights.scm` in &rtp
--]]

---@class TSQueryModule
local M = {}

local language = require("vim.treesitter.language")

local cthulhu = require("cthulhu")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("hal.treesitter.query", "info")

local api = vim.api

local predicate_handlers --todo: can be loaded from nvim runtime
do
  ---@alias TSMatch table<integer,TSNode>

  ---@alias TSPredicate fun(match: TSMatch, _, _, predicate: any[]): boolean

  -- Predicate handler receive the following arguments
  -- (match, pattern, bufnr, predicate)
  ---@type table<string,TSPredicate>
  predicate_handlers = {
    ["eq?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      if not node then return true end
      local node_text = vim.treesitter.get_node_text(node, source)

      local str ---@type string
      if type(predicate[3]) == "string" then
        -- (#eq? @aa "foo")
        str = predicate[3]
      else
        -- (#eq? @aa @bb)
        str = vim.treesitter.get_node_text(match[predicate[3]], source)
      end

      if node_text ~= str or str == nil then return false end

      return true
    end,

    ["lua-match?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      if not node then return true end
      local regex = predicate[3]
      return string.find(vim.treesitter.get_node_text(node, source), regex) ~= nil
    end,

    ["match?"] = (function()
      local magic_prefixes = { ["\\v"] = true, ["\\m"] = true, ["\\M"] = true, ["\\V"] = true }
      ---@private
      local function check_magic(str)
        if string.len(str) < 2 or magic_prefixes[string.sub(str, 1, 2)] then return str end
        return "\\v" .. str
      end

      local compiled_vim_regexes = setmetatable({}, {
        __index = function(t, pattern)
          local res = vim.regex(check_magic(pattern))
          rawset(t, pattern, res)
          return res
        end,
      })

      return function(match, _, source, pred)
        ---@cast match TSMatch
        local node = match[pred[2]]
        if not node then return true end
        ---@diagnostic disable-next-line no-unknown
        local regex = compiled_vim_regexes[pred[3]]
        return regex:match_str(vim.treesitter.get_node_text(node, source))
      end
    end)(),

    ["contains?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      if not node then return true end
      local node_text = vim.treesitter.get_node_text(node, source)

      for i = 3, #predicate do
        if string.find(node_text, predicate[i], 1, true) then return true end
      end

      return false
    end,

    ["any-of?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      if not node then return true end
      local node_text = vim.treesitter.get_node_text(node, source)

      -- Since 'predicate' will not be used by callers of this function, use it
      -- to store a string set built from the list of words to check against.
      local string_set = predicate["string_set"]
      if not string_set then
        string_set = {}
        for i = 3, #predicate do
          ---@diagnostic disable-next-line:no-unknown
          string_set[predicate[i]] = true
        end
        predicate["string_set"] = string_set
      end

      return string_set[node_text]
    end,
  }

  predicate_handlers["vim-match?"] = predicate_handlers["match?"]

  ---@param name string Name of the predicate, without leading #
  ---@param handler function(match:table<string,TSNode>, pattern:string, bufnr:integer, predicate:string[])
  ---   - see |vim.treesitter.query.add_directive()| for argument meanings
  ---@param force boolean|nil
  function M.add_predicate(name, handler, force)
    if predicate_handlers[name] and not force then error(string.format("Overriding %s", name)) end

    predicate_handlers[name] = handler
  end

  ---@return string[] List of supported predicates.
  function M.list_predicates() return vim.tbl_keys(predicate_handlers) end
end

local directive_handlers --todo: can be loaded from nvim runtime
do
  ---@class TSMetadata
  ---@field range Range
  ---@field [integer] TSMetadata
  ---@field [string] integer|string

  ---@alias TSDirective fun(match: TSMatch, _, _, predicate: (string|integer)[], metadata: TSMetadata)

  -- Predicate handler receive the following arguments
  -- (match, pattern, bufnr, predicate)

  -- Directives store metadata or perform side effects against a match.
  -- Directives should always end with a `!`.
  -- Directive handler receive the following arguments
  -- (match, pattern, bufnr, predicate, metadata)
  ---@type table<string,TSDirective>
  directive_handlers = {
    ["set!"] = function(_, _, _, pred, metadata)
      if #pred >= 3 and type(pred[2]) == "number" then
        -- (#set! @capture key value)
        local capture_id, key, value = pred[2], pred[3], pred[4]
        if not metadata[capture_id] then metadata[capture_id] = {} end
        metadata[capture_id][key] = value
      else
        -- (#set! key value)
        local key, value = pred[2], pred[3]
        metadata[key] = value or true
      end
    end,
    -- Shifts the range of a node.
    -- Example: (#offset! @_node 0 1 0 -1)
    ["offset!"] = function(match, _, _, pred, metadata)
      ---@cast pred integer[]
      local capture_id = pred[2]
      if not metadata[capture_id] then metadata[capture_id] = {} end

      local range = metadata[capture_id].range or { match[capture_id]:range() }
      local start_row_offset = pred[3] or 0
      local start_col_offset = pred[4] or 0
      local end_row_offset = pred[5] or 0
      local end_col_offset = pred[6] or 0

      range[1] = range[1] + start_row_offset
      range[2] = range[2] + start_col_offset
      range[3] = range[3] + end_row_offset
      range[4] = range[4] + end_col_offset

      -- If this produces an invalid range, we just skip it.
      if range[1] < range[3] or (range[1] == range[3] and range[2] <= range[4]) then metadata[capture_id].range = range end
    end,

    -- Transform the content of the node
    -- Example: (#gsub! @_node ".*%.(.*)" "%1")
    ["gsub!"] = function(match, _, bufnr, pred, metadata)
      assert(#pred == 4)

      local id = pred[2]
      assert(type(id) == "number")

      local node = match[id]
      local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""

      if not metadata[id] then metadata[id] = {} end

      local pattern, replacement = pred[3], pred[4]
      assert(type(pattern) == "string")
      assert(type(replacement) == "string")

      metadata[id].text = text:gsub(pattern, replacement)
    end,
  }

  ---@param name string Name of the directive, without leading #
  ---@param handler function(match:table<string,TSNode>, pattern:string, bufnr:integer, predicate:string[], metadata:table)
  ---   - match: see |treesitter-query|
  ---      - node-level data are accessible via `match[capture_id]`
  ---   - pattern: see |treesitter-query|
  ---   - predicate: list of strings containing the full directive being called, e.g.
  ---     `(node (#set! conceal "-"))` would get the predicate `{ "#set!", "conceal", "-" }`
  ---@param force boolean|nil
  function M.add_directive(name, handler, force)
    if directive_handlers[name] and not force then error(string.format("Overriding %s", name)) end

    directive_handlers[name] = handler
  end

  ---@return string[] List of supported directives.
  function M.list_directives() return vim.tbl_keys(directive_handlers) end
end

local Query --todo: can be loaded from nvim runtime
do
  ---@class TSQueryInfo
  ---@field captures table
  ---@field patterns table<string,any[][]>

  ---@class Query
  ---@field captures string[] List of captures used in query
  ---@field info TSQueryInfo Contains used queries, predicates, directives
  ---@field query userdata Parsed query
  Query = {}
  Query.__index = Query

  local function is_directive(name) return string.sub(name, -1) == "!" end

  local function xor(x, y) return (x or y) and not (x and y) end

  ---@param start integer
  ---@param stop integer
  ---@param node TSNode
  ---@return integer, integer
  local function value_or_node_range(start, stop, node)
    if start == nil and stop == nil then
      local node_start, _, node_stop, _ = node:range()
      return node_start, node_stop + 1 -- Make stop inclusive
    end

    return start, stop
  end

  ---@private
  ---@param match TSMatch
  ---@param pattern string
  ---@param source integer|string
  function Query:match_preds(match, pattern, source)
    local preds = self.info.patterns[pattern]

    for _, pred in pairs(preds or {}) do
      -- Here we only want to return if a predicate DOES NOT match, and
      -- continue on the other case. This way unknown predicates will not be considered,
      -- which allows some testing and easier user extensibility (#12173).
      -- Also, tree-sitter strips the leading # from predicates for us.
      local pred_name ---@type string

      local is_not ---@type boolean

      -- Skip over directives... they will get processed after all the predicates.
      if not is_directive(pred[1]) then
        if string.sub(pred[1], 1, 4) == "not-" then
          pred_name = string.sub(pred[1], 5)
          is_not = true
        else
          pred_name = pred[1]
          is_not = false
        end

        local handler = predicate_handlers[pred_name]

        if not handler then
          error(string.format("No handler for %s", pred[1]))
          return false
        end

        local pred_matches = handler(match, pattern, source, pred)

        if not xor(is_not, pred_matches) then return false end
      end
    end
    return true
  end

  ---@private
  ---@param match TSMatch
  ---@param metadata TSMetadata
  function Query:apply_directives(match, pattern, source, metadata)
    local preds = self.info.patterns[pattern]

    for _, pred in pairs(preds or {}) do
      if is_directive(pred[1]) then
        local handler = directive_handlers[pred[1]]

        if not handler then
          error(string.format("No handler for %s", pred[1]))
          return
        end

        handler(match, pattern, source, pred, metadata)
      end
    end
  end

  ---@param node TSNode under which the search will occur
  ---@param source (integer|string) Source buffer or string to extract text from
  ---@param start integer Starting line for the search
  ---@param stop integer Stopping line for the search (end-exclusive)
  ---@return (fun(): integer, TSNode, TSMetadata): capture id, capture node, metadata
  function Query:iter_captures(node, source, start, stop)
    if type(source) == "number" and source == 0 then source = api.nvim_get_current_buf() end

    start, stop = value_or_node_range(start, stop, node)

    local raw_iter = node:_rawquery(self.query, true, start, stop)
    ---@private
    local function iter()
      local capture, captured_node, match = raw_iter()
      local metadata = {}

      if match ~= nil then
        local active = self:match_preds(match, match.pattern, source)
        match.active = active
        if not active then
          return iter() -- tail call: try next match
        end

        self:apply_directives(match, match.pattern, source, metadata)
      end
      return capture, captured_node, metadata
    end
    return iter
  end

  ---@param node TSNode under which the search will occur
  ---@param source (integer|string) Source buffer or string to search
  ---@param start integer Starting line for the search
  ---@param stop integer Stopping line for the search (end-exclusive)
  ---
  ---@return (fun(): integer, table<integer,TSNode>, table): pattern id, match, metadata
  function Query:iter_matches(node, source, start, stop)
    if type(source) == "number" and source == 0 then source = api.nvim_get_current_buf() end

    start, stop = value_or_node_range(start, stop, node)

    local raw_iter = node:_rawquery(self.query, false, start, stop)
    ---@cast raw_iter fun(): string, any
    local function iter()
      local pattern, match = raw_iter()
      local metadata = {}

      if match ~= nil then
        local active = self:match_preds(match, pattern, source)
        if not active then
          return iter() -- tail call: try next match
        end

        self:apply_directives(match, pattern, source, metadata)
      end
      return pattern, match, metadata
    end
    return iter
  end
end

do --M.get_files
  ---@param lang string Language to get query for
  ---@param query_name string Name of the query to load (e.g., "highlights")
  ---@return string[]
  function M.get_files(lang, query_name)
    ---disable folds, injections group
    if query_name ~= "highlights" then return {} end
    local pattern = string.format("queries/%s/%s.scm", lang, query_name)
    return api.nvim_get_runtime_file(pattern, false)
  end
end

do --M.get
  local function file_content(filename)
    local file = assert(io.open(filename, "r"))
    local content = file:read("*a")
    io.close(file)
    return content
  end

  ---@param filenames string[]
  local function load_query_string(filenames)
    local contents = {}
    for _, filename in ipairs(filenames) do
      table.insert(contents, file_content(filename))
    end
    return table.concat(contents, "")
  end

  ---for query_string rather than volatile Query
  local cache = {}
  do
    ---@type {[string]: {[string]: Query|false}}
    cache.store = dictlib.CappedDict(16)
    function cache:get(lang, query_name) return dictlib.get(self.store, lang, query_name) end
    function cache:set(lang, query_name, value)
      if self.store[lang] == nil then self.store[lang] = dictlib.CappedDict(8) end
      self.store[lang][query_name] = value
    end
  end

  ---@param lang string Language to use for the query
  ---@param query_name string Name of the query (e.g. "highlights")
  ---@return Query?
  function M.get(lang, query_name)
    local query_string = cache:get(lang, query_name)
    if query_string == nil then
      local query_files = M.get_files(lang, query_name)
      query_string = load_query_string(query_files)
      cache:set(lang, query_name, query_string)
    end

    if #query_string == 0 then return end
    return M.parse(lang, query_string)
  end
end

do --M.parse
  local cache = {}
  do
    ---@type {[string]: {[string]: Query}}
    cache.store = dictlib.CappedDict(16)
    function cache:get(lang, query_string)
      local queries = self.store[lang]
      if queries == nil then return end
      return queries[cthulhu.md5(query_string)]
    end
    function cache:set(lang, query_string, value)
      if self.store[lang] == nil then self.store[lang] = dictlib.CappedDict(128, true) end
      self.store[lang][cthulhu.md5(query_string)] = value
    end
  end

  ---@param lang string Language to use for the query
  ---@param query_string string Query in s-expr syntax
  ---@return Query
  function M.parse(lang, query_string)
    language.add(lang)

    local cached = cache:get(lang, query_string)
    if cached then return cached end

    local query
    do
      jelly.debug("parsing lang=%s, query='%s'", lang, query_string)
      local native = vim._ts_parse_query(lang, query_string)
      local info = native:inspect()
      query = setmetatable({ query = native, info = info, captures = info.captures }, Query)
    end
    cache:set(lang, query_string, query)
    return query
  end
end

do -- disabled apis
  local function noway() error("inaccessible") end
  M.set = noway
  M.get_query_files = noway
  M.set_query = noway
  M.get_query = noway
  M.parse_query = noway
  M.get_range = noway
  M.get_node_text = noway
end

return M
