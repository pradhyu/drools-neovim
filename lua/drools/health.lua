-- lua/drools/health.lua
-- :checkhealth drools health checker module for Neovim

local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

function M.check()
  start("drools.nvim health check")

  -- Check Neovim version
  if vim.fn.has("nvim-0.8.0") == 1 then
    ok("Neovim version >= 0.8.0")
  else
    warn("Neovim version < 0.8.0. Some features may not work as expected.")
  end

  -- Check Filetype detection
  local ft_ok = vim.filetype ~= nil
  if ft_ok then
    ok("vim.filetype API is available")
  else
    warn("vim.filetype API not available; using legacy fallback")
  end

  -- Check Snippet integration
  local has_luasnip = pcall(require, "luasnip")
  if has_luasnip then
    ok("LuaSnip plugin found (snippets enabled)")
  else
    warn("LuaSnip plugin not found (install LuaSnip to enable pre-packaged Drools snippets)")
  end

  -- Check Lspconfig integration
  local has_lspconfig = pcall(require, "lspconfig")
  if has_lspconfig then
    ok("nvim-lspconfig plugin available for Drools Language Server setup")
  else
    warn("nvim-lspconfig not installed (built-in Lua linter will be used as fallback)")
  end
end

return M
