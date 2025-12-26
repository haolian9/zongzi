local ex = require("infra.ex")
local ni = require("infra.ni")

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

do --customized version of $VIMRUNTIME/filetype.lua
  --* no vimscripts.vim fallback
  --* no StdinReadPost autocmd
  --* no honoring ftdetect/*

  assert(vim.g.did_load_filetypes ~= 1)
  vim.g.did_load_filetypes = 1

  local aug = ni.create_augroup("vim://ftdetect", { clear = true })

  ni.create_autocmd({ "BufRead", "BufNewFile" }, {
    group = aug,
    callback = function(args)
      assert(ni.buf_is_valid(args.buf))

      local ft, on_detect = vim.filetype.match({ filename = args.file, buf = args.buf })

      --yes, file detecting can be failed
      --no detecting configuration files which is just not worth it
      if not ft then return end

      if on_detect then on_detect(args.buf) end
      ni.buf_call(args.buf, function() ex("setfiletype", ft) end)
    end,
  })
end
