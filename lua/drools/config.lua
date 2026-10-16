-- lua/drools/config.lua
-- Plugin options & configuration defaults

local M = {}

M.defaults = {
  treesitter = {
    enable = true,
    prefer_treesitter_folding = true,
  },
  highlight = {
    enable = true,
  },
  linter = {
    enable = true,
    mode = "insert_leave", -- Options: "insert_leave" (default, updates on exiting Insert mode), "live" (updates DURING Insert mode), "on_save" (updates on file save)
    debounce_ms = 100,
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
  mouse = {
    enable = false,
    hover = false,
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
  return M.options
end

return M
