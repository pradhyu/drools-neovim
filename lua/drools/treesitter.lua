-- lua/drools/treesitter.lua
-- Tree-sitter integration module for Drools Rule Language

local M = {}

--- Register Drools filetype and tree-sitter parser configuration
function M.setup(opts)
  opts = opts or {}
  if opts.enable == false then
    return
  end

  -- Register drools language mapping with Neovim tree-sitter engine
  if vim.treesitter.language and vim.treesitter.language.register then
    pcall(vim.treesitter.language.register, "drools", { "drools", "dsl" })
  end

  -- Auto-start Tree-sitter on opening Drools buffers
  local group = vim.api.nvim_create_augroup("DroolsTreesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "drools", "dsl" },
    callback = function(args)
      local bufnr = args.buf
      -- Enable Tree-sitter highlighting if parser is available
      local ok = pcall(vim.treesitter.start, bufnr, "drools")
      if ok then
        -- Set Tree-sitter as primary folding method if configured
        if opts.prefer_treesitter_folding then
          vim.wo[0][0].foldmethod = "expr"
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end
      end
    end,
  })
end



return M
