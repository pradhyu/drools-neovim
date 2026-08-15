-- lua/drools/init.lua
-- Main entrypoint for drools.nvim

local config = require("drools.config")
local linter = require("drools.linter")
local lsp = require("drools.lsp")
local snippets = require("drools.snippets")
local nav = require("drools.navigation")
local formatter = require("drools.formatter")
local runner = require("drools.runner")

local M = {}

--- Initialize plugin with user configuration
---@param user_opts table|nil Options table
function M.setup(user_opts)
  M.options = config.setup(user_opts)

  -- Setup Linter diagnostics
  if M.options.linter.enable then
    linter.setup(M.options.linter)
  end

  -- Setup LSP Server launcher
  if M.options.lsp.enable then
    lsp.setup(M.options.lsp)
  end

  -- Load snippets if enabled
  if M.options.snippets.enable then
    snippets.setup()
  end

  -- Register User Commands
  vim.api.nvim_create_user_command("DroolsLint", function()
    linter.lint(vim.api.nvim_get_current_buf())
  end, { desc = "Run static syntax analysis on current Drools file" })

  vim.api.nvim_create_user_command("DroolsFormat", function()
    formatter.format(vim.api.nvim_get_current_buf())
  end, { desc = "Auto-format current Drools buffer" })

  vim.api.nvim_create_user_command("DroolsSymbols", function()
    nav.show_symbols(vim.api.nvim_get_current_buf())
  end, { desc = "Show Drools rules and symbols outline" })

  vim.api.nvim_create_user_command("DroolsGotoDefinition", function()
    nav.goto_definition()
  end, { desc = "Jump to fact type or rule definition" })

  vim.api.nvim_create_user_command("DroolsTest", function()
    runner.run_tests()
  end, { desc = "Run Maven or Gradle test suite for Drools rules" })

  vim.api.nvim_create_user_command("DroolsReload", function()
    M.reload()
    vim.notify("drools.nvim reloaded successfully!", vim.log.levels.INFO)
  end, { desc = "Reload drools.nvim modules" })
end

--- Reload all drools.nvim modules and re-initialize
function M.reload()
  local saved_opts = M.options
  for k in pairs(package.loaded) do
    if k:match("^drools") then
      package.loaded[k] = nil
    end
  end
  require("drools").setup(saved_opts)
  if vim.bo.filetype == "drools" then
    require("drools.linter").lint(vim.api.nvim_get_current_buf())
  end
end

return M
