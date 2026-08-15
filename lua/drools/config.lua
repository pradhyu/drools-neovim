-- lua/drools/config.lua
-- Plugin options & configuration defaults

local M = {}

M.defaults = {
  treesitter = {
    enable = true,
    prefer_treesitter_folding = true,
    use_ast_linter = true,
  },
  highlight = {
    enable = true,
    use_treesitter = true,
    fallback_regex = true,
  },
  linter = {
    enable = true,
    on_save = true,
    on_change = true,
    debounce_ms = 300,
  },
  lsp = {
    enable = false,
    cmd = nil,
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
