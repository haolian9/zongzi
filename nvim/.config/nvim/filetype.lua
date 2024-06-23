vim.filetype.add({
  extension = {
    c = "c", -- to avoid filetype.detect
    h = "c", -- to avoidfiletype.detect
    sh = "bash", -- to avoidfiletype.detect
    bash = "bash", -- to avoidfiletype.detect
    wiki = "wiki",
  },
  filename = {
    -- otherwise shellcheck will consume all the cpu resources then make the os no responsible
    configure = "OFF",
    PKGBUILD = "OFF",
  },
  pattern = {
    [".*/%.ssh/config.*"] = "sshconfig",
  },
})
