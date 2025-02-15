local ropes = require("string.buffer")

local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("scripts.geni", "debug")
local resolve_plugin_root = require("infra.resolve_plugin_root")
local strlib = require("infra.strlib")

local deprecates = itertools.toset({
  "nvim_buf_clear_highlight",
  "nvim_buf_get_number",
  "nvim_buf_get_option",
  "nvim_buf_set_option",
  "nvim_buf_set_virtual_text",
  "nvim_command_output",
  "nvim_exec",
  "nvim_get_hl_by_id",
  "nvim_get_hl_by_name",
  "nvim_get_option",
  "nvim_get_option_info",
  "nvim_set_option",
  "nvim_win_get_option",
  "nvim_win_set_option",
})

local function main()
  local groups = {} ---@type [string, [string, string][]][]
  local left_max = 0
  do
    local dict = { x = {} } ---@type {[string]: [string,string][]}
    for name in pairs(vim.api) do
      if deprecates[name] then goto continue end

      local group, left, right
      if strlib.startswith(name, "nvim__") then
        local short = string.sub(name, #"nvim__" + 1)
        group = "x"
        left = "x." .. short
        right = name
      else
        assert(strlib.startswith(name, "nvim_"))
        local short = string.sub(name, #"nvim_" + 1)
        group = assert(strlib.iter_splits(short, "_")())
        left = short
        right = name
      end

      if dict[group] == nil then dict[group] = {} end
      table.insert(dict[group], { left, right })
      if left_max < #left then left_max = #left end

      ::continue::
    end
    for group, names in pairs(dict) do
      table.sort(names, function(a, b) return a[2] < b[2] end)
      table.insert(groups, { group, names })
    end
    table.sort(groups, function(a, b) return a[1] < b[1] end)
  end

  local dest_fpath = string.format("%s/%s", resolve_plugin_root("infra", "ni.lua"), "lua/infra/ni.lua")
  jelly.info("dest: %s", dest_fpath)

  do
    local buf = ropes.new()
    buf:putf("---generated by scripts/geni.lua at %s\n", os.date("%Y-%m-%d"))
    buf:put("---@diagnostic disable: undefined-field\n")
    buf:put("--stylua: ignore start\n")
    buf:put("\n")
    buf:put("local M = { x = {} }\n")
    buf:put("\n")
    buf:put("local api = vim.api\n")
    local seen = {} ---@type {[string]:true}
    local api_count = 0
    for _, group in pairs(groups) do
      buf:put("\n")
      local names = group[2]
      for _, tuple in ipairs(names) do
        local left, right = unpack(tuple)
        assert(not seen[right])
        seen[right] = true
        api_count = api_count + 1
        buf:putf("M.%s%s= api.%s\n", left, string.rep(" ", (left_max - #left) + 1), right)
      end
    end
    jelly.debug("api count: %d", api_count)
    buf:put("\n", "return M\n")
    buf:put("--stylua: ignore end\n")

    local file = assert(io.open(dest_fpath, "w"))
    file:write(buf:get())
    file:close()
  end
end

main()
