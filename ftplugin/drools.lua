-- ftplugin/drools.lua
-- Buffer-local settings and keymaps for Drools files

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
vim.keymap.set("n", "gd", "<cmd>DroolsGotoDefinition<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Goto Definition" }))
vim.keymap.set("n", "K", "<cmd>DroolsHover<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Show Hover Documentation" }))
vim.keymap.set("n", "<C-LeftMouse>", "<cmd>DroolsHover<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Ctrl+Click Definition / Hover" }))
vim.keymap.set("n", "<leader>dh", "<cmd>DroolsHover<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Show Specification Hover" }))
vim.keymap.set("n", "<leader>dl", "<cmd>DroolsLint<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Run Linter" }))
vim.keymap.set("n", "<leader>df", "<cmd>DroolsFormat<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Format Buffer" }))
vim.keymap.set("n", "<leader>ds", "<cmd>DroolsSymbols<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Outline Symbols" }))
vim.keymap.set("n", "<leader>da", "<cmd>DroolsAgenda<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Rule Agenda Inspector" }))
vim.keymap.set("n", "<leader>ca", "<cmd>DroolsCodeAction<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Quick Fix Actions" }))
vim.keymap.set("n", "<leader>dt", "<cmd>DroolsTest<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Run Test Suite" }))

-- Structural Folding Keymaps (Normal & Visual mode)
vim.keymap.set({ "n", "v" }, "<leader>zR", "<cmd>DroolsFoldRule<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Rule Block" }))
vim.keymap.set({ "n", "v" }, "<leader>zW", "<cmd>DroolsFoldWhen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold When Block" }))
vim.keymap.set({ "n", "v" }, "<leader>zT", "<cmd>DroolsFoldThen<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold Then Block" }))
vim.keymap.set("n", "<leader>zA", "<cmd>DroolsFoldAllRules<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Fold All Rules" }))
vim.keymap.set("n", "<leader>zF", "<cmd>DroolsFoldExcept<CR>", vim.tbl_extend("force", opts, { desc = "Drools: Focus Mode (Fold Except Pattern)" }))

-- Buffer-local undo settings
vim.b.undo_ftplugin = "setlocal commentstring< comments< tabstop< shiftwidth< softtabstop< expandtab< foldmethod<"
