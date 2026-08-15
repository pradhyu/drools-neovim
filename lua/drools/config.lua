-- lua/drools/config.lua
-- Plugin options & configuration defaults

local M = {}

M.defaults = {
  highlight = {
    enable = true,
  },
  linter = {
    enable = true,
    on_save = true,
    on_change = false,
  },
  lsp = {
    enable = false,
    cmd = { "java", "-jar", "drools-lsp-server.jar" },
    filetypes = { "drools" },
    root_dir = nil,
  },
  snippets = {
    enable = true,
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
  return M.options
end

return M
