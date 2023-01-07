local M = {}

local api = vim.api

function M.setup()
  require("guwen.setup")()

  api.nvim_create_user_command("Guwen", function(args)
    require("guwen")[args.args]()
  end, {
    nargs = 1,
    complete = function()
      return require("guwen")._completion
    end,
  })
end

return M
