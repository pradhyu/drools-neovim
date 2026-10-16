-- lua/drools/treesitter.lua
-- Tree-sitter integration module for Drools Rule Language

local M = {}

local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local src_dir = plugin_dir .. "/tree-sitter-drools/src"
local parser_so = plugin_dir .. "/parser/drools.so"

--- Compile the bundled grammar into <plugin>/parser/drools.so (which is on 'runtimepath').
--- Rebuilds when parser.c is newer than the shared library or when `force` is set.
function M.build(force)
  local src = src_dir .. "/parser.c"
  if vim.fn.filereadable(src) == 0 then
    return false, "parser.c not found at " .. src
  end
  local so_time = vim.fn.getftime(parser_so)
  if not force and so_time ~= -1 and so_time >= vim.fn.getftime(src) then
    return true
  end
  local cc = vim.env.CC or (vim.fn.executable("cc") == 1 and "cc") or (vim.fn.executable("gcc") == 1 and "gcc")
    or (vim.fn.executable("clang") == 1 and "clang")
  if not cc then
    return false, "no C compiler (cc/gcc/clang) found to build the Drools tree-sitter parser"
  end
  vim.fn.mkdir(plugin_dir .. "/parser", "p")
  local cmd = { cc, "-o", parser_so, "-I", src_dir, "-shared", "-fPIC", "-Os", src }
  if vim.fn.filereadable(src_dir .. "/scanner.c") == 1 then
    table.insert(cmd, src_dir .. "/scanner.c")
  end
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return false, "failed to build Drools parser: " .. out
  end
  -- Drop any cached language so the fresh build is picked up
  pcall(function() vim.treesitter.language.add("drools", { path = parser_so }) end)
  return true
end

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

  vim.api.nvim_create_user_command("DroolsTSBuild", function()
    local ok, err = M.build(true)
    vim.notify(ok and "Drools tree-sitter parser built: " .. parser_so or err,
      ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end, { desc = "Rebuild the bundled Drools tree-sitter parser" })

  local built = false

  -- Auto-start Tree-sitter on opening Drools buffers
  local group = vim.api.nvim_create_augroup("DroolsTreesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "drools", "dsl" },
    callback = function(args)
      local bufnr = args.buf
      if not built and opts.auto_build ~= false then
        built = true
        local ok, err = M.build(false)
        if not ok then
          vim.notify_once("[drools] " .. err, vim.log.levels.WARN)
        end
      end
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
