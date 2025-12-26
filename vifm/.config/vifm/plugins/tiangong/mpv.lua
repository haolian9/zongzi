local kv = {
  --find is necessary when ./{a/b.mp4,c/d.mp4,e.mp4}
  [""] = [[mpv $(fd --type=file -e mp4 -e webm)]],
  ["monthly"] = [[mpv $(find -type f -name '*.mp4' -newermt '1 month ago')]],
  ["weekly"] = [[mpv $(find -type f -name '*.mp4' -newermt '1 week ago')]],
  ["grid"] = [[tmux splitw -v -l 3 pp .]],
}

local function handler(info)
  local cmd = kv[info.args]
  if cmd == nil then return end
  vifm.startjob({ cmd = cmd, iomode = "" })
end

local function startswith(a, b)
  if a == "" or b == "" then return false end
  if #a < #b then return false end
  return string.sub(a, 1, #b) == b
end

local full_matches = {}
for k, _ in pairs(kv) do
  table.insert(full_matches, k)
end

local function complete(info)
  local matches = {}
  local input = info.args
  if input == "" then
    matches = full_matches
  else
    for k, _ in pairs(kv) do
      if startswith(k, input) then table.insert(matches, k) end
    end
  end
  return { offset = 0, matches = matches }
end

assert(vifm.cmds.add({ name = "mpv", description = "mpv .", minargs = 0, maxargs = 1, handler = handler, complete = complete }))
