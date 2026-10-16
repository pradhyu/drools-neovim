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

  -- Check java executable
  if vim.fn.executable("java") == 1 then
    ok("Java executable found (required for LSP)")
  else
    warn("Java executable not found in PATH (required for Drools LSP)")
  end

  -- Check Tree-sitter parser
  if pcall(vim.treesitter.language.inspect, "drools") then
    ok("Tree-sitter 'drools' parser is installed and active")
  else
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
    if vim.fn.filereadable(plugin_dir .. "/parser/drools.so") == 1 then
      ok("Tree-sitter 'drools' compiled shared library found at parser/drools.so")
    else
      warn("Tree-sitter 'drools' parser not built yet (run :DroolsTSBuild to compile the bundled parser)")
    end
  end

  -- Check LSP jar if enabled
  local config_ok, config = pcall(require, "drools.config")
  if config_ok and config.options and config.options.lsp and config.options.lsp.enable then
    local jar_path = nil
    for i, arg in ipairs(config.options.lsp.cmd or {}) do
      if arg == "-jar" and config.options.lsp.cmd[i + 1] then
        jar_path = config.options.lsp.cmd[i + 1]
        break
      end
    end
    if jar_path then
      local expanded_path = vim.fn.expand(jar_path)
      if vim.fn.filereadable(expanded_path) == 1 then
        ok("Drools LSP server jar found at: " .. jar_path)
      else
        error("Drools LSP server jar not found at: " .. jar_path)
      end
    else
      warn("LSP is enabled but -jar path not found in lsp.cmd")
    end
  end
end

return M
