vim.filetype.add({
  extension = {
    c = "c", -- no need to filetype.detect
    h = "c", -- no need to filetype.detect
    sh = "bash", -- no need to filetype.detect
    bash = "bash", -- no need to filetype.detect
    wiki = "wiki",
  },
  filename = {
    -- or shellcheck will consume all the cpu resources then make the os no responsible
    configure = "OFF",
    PKGBUILD = "OFF",
  },
})
