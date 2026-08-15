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

--- Get Tree-sitter AST error diagnostics for current buffer
---@param bufnr number Buffer handle
---@return table List of diagnostic items
function M.get_parse_errors(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local diagnostics = {}

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "drools")
  if not ok or not parser then
    return diagnostics
  end

  local tree = parser:parse()[1]
  if not tree then
    return diagnostics
  end

  local root = tree:root()
  local query_str = "(ERROR) @error (MISSING) @missing"
  local q_ok, query = pcall(vim.treesitter.query.parse, "drools", query_str)
  if not q_ok or not query then
    return diagnostics
  end

  for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
    local start_row, start_col, end_row, end_col = node:range()
    local capture_name = query.captures[id]
    local node_type = node:type()
    
    local msg = string.format("Tree-sitter syntax error: unexpected '%s'", node_type == "ERROR" and "syntax" or node_type)
    if capture_name == "missing" then
      msg = "Tree-sitter syntax error: missing required token"
    end

    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = start_row,
      col = start_col,
      end_lnum = end_row,
      end_col = end_col,
      severity = vim.diagnostic.severity.ERROR,
      message = msg,
      source = "drools-treesitter",
    })
  end

  return diagnostics
end

return M
