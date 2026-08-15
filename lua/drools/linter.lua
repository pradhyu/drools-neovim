-- lua/drools/linter.lua
-- Built-in static syntax checker and diagnostic provider for Drools files (.drl)

local M = {}

local ns = vim.api.nvim_create_namespace("drools_linter")

--- Perform linting on a specific buffer
---@param bufnr number Buffer number
function M.lint(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "drools" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagnostics = {}

  local has_package = false
  local current_rule = nil
  local seen_when = false
  local seen_then = false
  local paren_stack = {}

  for i, line in ipairs(lines) do
    local lnum = i - 1 -- 0-indexed line number for diagnostics
    local trimmed = line:gsub("//.*$", ""):gsub("/%*.-%*/", ""):match("^%s*(.-)%s*$")

    if trimmed ~= "" then
      -- 1. Check Package declaration
      if trimmed:match("^package%s+") then
        has_package = true
      end

      -- 2. Rule declaration
      local rule_name = trimmed:match("^rule%s+[\"']?(.-)[\"']?$")
      if rule_name then
        if current_rule then
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = lnum,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = string.format("Nested or unclosed rule definition before rule '%s'", rule_name),
            source = "drools-linter",
          })
        end
        current_rule = { line = lnum, name = rule_name }
        seen_when = false
        seen_then = false
      end

      -- 3. Check section keywords
      if trimmed:match("^when$") then
        if not current_rule then
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = lnum,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = "'when' block found outside of a 'rule'",
            source = "drools-linter",
          })
        else
          seen_when = true
        end
      end

      if trimmed:match("^then$") then
        if not current_rule then
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = lnum,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = "'then' block found outside of a 'rule'",
            source = "drools-linter",
          })
        elseif not seen_when then
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = lnum,
            col = 0,
            severity = vim.diagnostic.severity.WARN,
            message = "'then' clause found before 'when' clause in rule",
            source = "drools-linter",
          })
        else
          seen_then = true
        end
      end

      -- 4. Check End of rule/query/declare block
      if trimmed:match("^end$") then
        if current_rule then
          if not seen_when then
            table.insert(diagnostics, {
              bufnr = bufnr,
              lnum = current_rule.line,
              col = 0,
              severity = vim.diagnostic.severity.WARN,
              message = string.format("Rule '%s' is missing a 'when' condition block", current_rule.name),
              source = "drools-linter",
            })
          end
          if not seen_then then
            table.insert(diagnostics, {
              bufnr = bufnr,
              lnum = current_rule.line,
              col = 0,
              severity = vim.diagnostic.severity.WARN,
              message = string.format("Rule '%s' is missing a 'then' action block", current_rule.name),
              source = "drools-linter",
            })
          end
          current_rule = nil
          seen_when = false
          seen_then = false
        end
      end

      -- 5. Track balanced parentheses across lines (ignoring string literals & comments)
      local code_no_strings = line:gsub("//.*$", ""):gsub("/%*.-%*/", ""):gsub('"([^"\\]|\\.)*"', '""'):gsub("'([^'\\]|\\.)*'", "''")
      for col = 1, #code_no_strings do
        local char = code_no_strings:sub(col, col)
        if char == "(" then
          table.insert(paren_stack, { lnum = lnum, col = col - 1 })
        elseif char == ")" then
          if #paren_stack > 0 then
            table.remove(paren_stack)
          else
            table.insert(diagnostics, {
              bufnr = bufnr,
              lnum = lnum,
              col = col - 1,
              severity = vim.diagnostic.severity.ERROR,
              message = "Unmatched closing parenthesis ')'",
              source = "drools-linter",
            })
          end
        end
      end
    end
  end

  -- Add diagnostics for any unclosed '(' remaining in stack
  for _, unclosed in ipairs(paren_stack) do
    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = unclosed.lnum,
      col = unclosed.col,
      severity = vim.diagnostic.severity.ERROR,
      message = "Unmatched opening parenthesis '('",
      source = "drools-linter",
    })
  end

  -- Package warning if file has rules but no package
  if not has_package and #lines > 0 then
    table.insert(diagnostics, 1, {
      bufnr = bufnr,
      lnum = 0,
      col = 0,
      severity = vim.diagnostic.severity.WARN,
      message = "Missing 'package' declaration at the top of the file",
      source = "drools-linter",
    })
  end

  -- Unclosed rule warning at EOF
  if current_rule then
    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = current_rule.line,
      col = 0,
      severity = vim.diagnostic.severity.ERROR,
      message = string.format("Rule '%s' is missing closing 'end' statement", current_rule.name),
      source = "drools-linter",
    })
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

function M.setup(opts)
  local group = vim.api.nvim_create_augroup("DroolsLinter", { clear = true })
  
  if opts.on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      pattern = "*.drl",
      callback = function(args)
        M.lint(args.buf)
      end,
    })
  end

  if opts.on_change then
    vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
      group = group,
      pattern = "*.drl",
      callback = function(args)
        M.lint(args.buf)
      end,
    })
  end

  -- Initial run on file open
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "*.drl",
    callback = function(args)
      M.lint(args.buf)
    end,
  })
end

return M
