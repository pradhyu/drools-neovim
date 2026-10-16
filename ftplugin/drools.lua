-- ftplugin/drools.lua
-- Buffer-local settings and ergonomic keymaps for Drools files

local bo = vim.bo

-- Comments configuration
bo.commentstring = "// %s"
bo.comments = "s1:/*,mb:*,ex:*/,://"

-- Tabulation and indentation defaults
bo.tabstop = 4
bo.shiftwidth = 4
bo.softtabstop = 4
bo.expandtab = true

-- Folding settings & visual gutter fold column (> / v / │)
pcall(function()
  require("drools.folding").setup_fold_display(0)
end)

-- Buffer-local keymaps
local opts = { buffer = true, silent = true }

-- Navigation & Definition Lookups (Keyboard gd/K and Ctrl+Click hover)
vim.keymap.set("n", "gd", "<cmd>DroolsGotoDefinition<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Goto Definition" }))
vim.keymap.set("n", "K", "<cmd>DroolsHover<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Show Hover Documentation" }))
vim.keymap.set({ "n", "v" }, "<C-LeftMouse>", function()
  require("drools.hover").handle_ctrl_click()
end, vim.tbl_extend("force", opts, { desc = "Drools: Ctrl+Click Hover" }))

vim.keymap.set("n", "<leader>dh", "<cmd>DroolsHover<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Show Specification Hover" }))
vim.keymap.set("n", "<leader>ds", "<cmd>DroolsSymbols<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Outline Symbols (Quickfix)" }))
vim.keymap.set("n", "<leader>dl", "<cmd>DroolsLint<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Run Linter / Diagnostics" }))
vim.keymap.set("n", "<leader>df", "<cmd>DroolsFormat<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Format Buffer" }))
vim.keymap.set("n", "<leader>da", "<cmd>DroolsAgenda<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Rule Agenda Inspector" }))
vim.keymap.set("n", "<leader>ca", "<cmd>DroolsCodeAction<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Quick Fix Actions" }))
vim.keymap.set("n", "<leader>dt", "<cmd>DroolsTest<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Run Test Suite" }))
vim.keymap.set("n", "<leader>de", "<cmd>DroolsExpandDSL<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Expand DSL Preview" }))
vim.keymap.set("n", "<leader>th", "<cmd>DroolsToggleSectionHighlight<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Toggle Section Highlight" }))

-- Motion & Rule Traversal
vim.keymap.set("n", "]r", function()
  vim.fn.search([[^\s*rule\>]], "W")
end, vim.tbl_extend("force", opts, { desc = "Drools: Next Rule" }))

vim.keymap.set("n", "[r", function()
  vim.fn.search([[^\s*rule\>]], "bW")
end, vim.tbl_extend("force", opts, { desc = "Drools: Previous Rule" }))

vim.keymap.set("n", "]w", function()
  vim.fn.search([[^\s*when:\?\s*$]], "W")
end, vim.tbl_extend("force", opts, { desc = "Drools: Next When Block" }))

vim.keymap.set("n", "[w", function()
  vim.fn.search([[^\s*when:\?\s*$]], "bW")
end, vim.tbl_extend("force", opts, { desc = "Drools: Previous When Block" }))

vim.keymap.set("n", "]t", function()
  vim.fn.search([=[^\s*then\(\[[^]]*\]\)\?:\?\s*$]=], "W")
end, vim.tbl_extend("force", opts, { desc = "Drools: Next Then Block" }))

vim.keymap.set("n", "[t", function()
  vim.fn.search([=[^\s*then\(\[[^]]*\]\)\?:\?\s*$]=], "bW")
end, vim.tbl_extend("force", opts, { desc = "Drools: Previous Then Block" }))

vim.keymap.set("n", "]d", function()
  vim.diagnostic.goto_next()
end, vim.tbl_extend("force", opts, { desc = "Drools: Next Diagnostic" }))

vim.keymap.set("n", "[d", function()
  vim.diagnostic.goto_prev()
end, vim.tbl_extend("force", opts, { desc = "Drools: Previous Diagnostic" }))

-- Structural Folding Keymaps (Lowercase and Uppercase variants for ergonomics)
vim.keymap.set({ "n", "v" }, "<leader>zr", "<cmd>DroolsFoldRule<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Current Rule" }))
vim.keymap.set({ "n", "v" }, "<leader>zR", "<cmd>DroolsFoldRule<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Current Rule" }))
vim.keymap.set({ "n", "v" }, "<leader>zw", "<cmd>DroolsFoldWhen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold When Block" }))
vim.keymap.set({ "n", "v" }, "<leader>zW", "<cmd>DroolsFoldWhen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold When Block" }))
vim.keymap.set({ "n", "v" }, "<leader>zt", "<cmd>DroolsFoldThen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Then Block" }))
vim.keymap.set({ "n", "v" }, "<leader>zT", "<cmd>DroolsFoldThen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Then Block" }))
vim.keymap.set("n", "<leader>za", "<cmd>DroolsFoldAllRules<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold All Rules in Buffer" }))
vim.keymap.set("n", "<leader>zA", "<cmd>DroolsFoldAllRules<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold All Rules in Buffer" }))
vim.keymap.set("n", "<leader>zaw", "<cmd>DroolsFoldAllWhen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold All When Blocks" }))
vim.keymap.set("n", "<leader>zat", "<cmd>DroolsFoldAllThen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold All Then Blocks" }))
vim.keymap.set("n", "<leader>zu", "<cmd>DroolsUnfoldAll<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Unfold All Blocks" }))
vim.keymap.set("n", "<leader>zU", "<cmd>DroolsUnfoldAll<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Unfold All Blocks" }))
vim.keymap.set("n", "<leader>zf", "<cmd>DroolsFoldExcept<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Focus Mode (Fold Except Pattern)" }))
vim.keymap.set("n", "<leader>zF", "<cmd>DroolsFoldExcept<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Focus Mode (Fold Except Pattern)" }))

-- Buffer-local undo settings
vim.b.undo_ftplugin = "setlocal commentstring< comments< tabstop< shiftwidth< softtabstop< expandtab< foldmethod<"
