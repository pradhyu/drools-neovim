-- lua/drools/snippets.lua
-- Snippet loader helper for LuaSnip / nvim-cmp integration

local M = {}

function M.setup()
  local has_luasnip, luasnip = pcall(require, "luasnip")
  if not has_luasnip then
    return false
  end

  local snippets_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/snippets"
  require("luasnip.loaders.from_vscode").lazy_load({ paths = { snippets_dir } })
  return true
end

return M
