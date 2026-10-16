-- lua/drools/init.lua
-- Main entrypoint for drools.nvim

local config = require("drools.config")
local treesitter = require("drools.treesitter")
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

  -- Setup Tree-sitter primary engine
  if M.options.treesitter and M.options.treesitter.enable ~= false then
    treesitter.setup(M.options.treesitter)
  end

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

  -- Setup Omni-completion provider
  require("drools.completion").setup()

  local hover = require("drools.hover")

  -- Register User Commands
  vim.api.nvim_create_user_command("DroolsHover", function()
    hover.show_hover()
  end, { desc = "Show specification hover or symbol definition popup" })

  vim.api.nvim_create_user_command("DroolsSpec", function(opts)
    local kw = opts.args
    if kw and kw ~= "" then
      if not hover.show_spec_doc(kw) then
        vim.notify("No specification doc found for keyword: " .. kw, vim.log.levels.WARN)
      end
    else
      hover.show_hover()
    end
  end, {
    nargs = "?",
    complete = function(ArgLead, CmdLine, CursorPos)
      local docs = hover.get_spec_docs()
      local keys = {}
      for k in pairs(docs) do
        if k:sub(1, #ArgLead):lower() == ArgLead:lower() then
          table.insert(keys, k)
        end
      end
      table.sort(keys)
      return keys
    end,
    desc = "Show official Drools specification documentation for a keyword",
  })

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

  vim.api.nvim_create_user_command("DroolsAgenda", function()
    require("drools.agenda").show_agenda()
  end, { desc = "Show rule execution priority agenda and loop warnings" })

  vim.api.nvim_create_user_command("DroolsCodeAction", function(opts)
    require("drools.code_action").show_quick_fixes(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Show quick-fix code actions menu" })

  -- Setup Structural Textobjects (ar, ir, aw, iw, at, it, ad, id)
  require("drools.textobjects").setup()

  vim.api.nvim_create_user_command("DroolsExpandDSL", function()
    require("drools.dsl").expand_dsl_buffer()
  end, { desc = "Expand .dsl domain mappings into raw DRL in a split preview" })

  -- Register Structural Folding & Focus Commands
  local folding = require("drools.folding")

  vim.api.nvim_create_user_command("DroolsFoldRule", function() folding.fold_rule() end, { desc = "Fold current rule block" })
  vim.api.nvim_create_user_command("DroolsFoldWhen", function() folding.fold_when() end, { desc = "Fold 'when' condition block" })
  vim.api.nvim_create_user_command("DroolsFoldThen", function() folding.fold_then() end, { desc = "Fold 'then' action block" })
  vim.api.nvim_create_user_command("DroolsFoldAllRules", function() folding.fold_all_rules() end, { desc = "Fold all rules in buffer" })
  vim.api.nvim_create_user_command("DroolsFoldAllWhen", function() folding.fold_all_when() end, { desc = "Fold all 'when' condition blocks in buffer" })
  vim.api.nvim_create_user_command("DroolsFoldAllThen", function() folding.fold_all_then() end, { desc = "Fold all 'then' action blocks in buffer" })
  vim.api.nvim_create_user_command("DroolsFoldExcept", function(opts) folding.fold_except(opts.args ~= "" and opts.args or nil) end, { nargs = "?", desc = "Fold all rules except those matching search pattern" })
  vim.api.nvim_create_user_command("DroolsUnfoldAll", function() folding.unfold_all() end, { desc = "Unfold all blocks in buffer" })

  -- Setup Section Background Highlighting (when vs then blocks)
  require("drools.highlight").setup(M.options.highlight)

  vim.api.nvim_create_user_command("DroolsToggleSectionHighlight", function()
    require("drools.highlight").toggle_highlights()
  end, { desc = "Toggle visual section background highlighting for 'when' vs 'then' blocks" })

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
    require("drools.folding").setup_fold_display(0)
    require("drools.linter").lint(vim.api.nvim_get_current_buf())
  end
end

return M
