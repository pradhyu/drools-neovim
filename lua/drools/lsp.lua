-- lua/drools/lsp.lua
-- Language Server Protocol (LSP) integration helper for Drools

local M = {}

--- Expand path variables like ~ to full absolute path
local function expand_cmd(cmd)
  if type(cmd) == "table" then
    local expanded = {}
    for _, arg in ipairs(cmd) do
      if type(arg) == "string" and arg:sub(1, 1) == "~" then
        table.insert(expanded, vim.fn.expand(arg))
      else
        table.insert(expanded, arg)
      end
    end
    return expanded
  end
  return cmd
end

function M.setup(opts)
  if not opts or not opts.enable then
    return
  end

  local cmd = expand_cmd(opts.cmd or { "java", "-jar", vim.fn.expand("~/.local/share/drools/drools-lsp-server.jar") })

  local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
  if not lspconfig_ok then
    -- Fallback to native vim.lsp.start if vim.lsp.start is available
    if vim.lsp and vim.lsp.start then
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "drools",
        callback = function(args)
          vim.lsp.start({
            name = "drools_ls",
            cmd = cmd,
            root_dir = opts.root_dir or vim.fs.dirname(vim.fs.find({ "pom.xml", "build.gradle", ".git" }, { upward = true })[1]),
          })
        end,
      })
    end
    return
  end

  -- Register with lspconfig configs if available
  local configs = require("lspconfig.configs")
  if not configs.drools_ls then
    configs.drools_ls = {
      default_config = {
        cmd = cmd,
        filetypes = { "drools" },
        root_dir = function(fname)
          return lspconfig.util.root_pattern("pom.xml", "build.gradle", ".git")(fname)
        end,
        settings = {},
      },
    }
  end

  lspconfig.drools_ls.setup(vim.tbl_extend("force", opts, { cmd = cmd }))
end

return M
