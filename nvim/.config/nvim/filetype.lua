vim.filetype.add({
  extension = {
    wiki = "wiki",
    mako = "mako",
  },
  filename = {
    -- or shellcheck will consume all the cpu resources then make the os no responsible
    configure = "OFF",
  },
  pattern = {
    ["vi%.*"] = "sh",
  },
})
