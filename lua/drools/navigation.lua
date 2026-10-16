-- lua/drools/navigation.lua
-- Symbol extraction, outline, and jump-to-definition for Drools files

local M = {}

--- Parse buffer lines and extract all Drools symbols (rules, declares, queries, functions)
---@param bufnr number Buffer number
---@return table Array of symbol objects { name, type, lnum, line }
function M.get_symbols(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local symbols = {}

  for i, line in ipairs(lines) do
    local trimmed = line:gsub("//.*$", ""):match("^%s*(.-)%s*$")
    if trimmed then
      -- Rule symbol
      local rule_name = trimmed:match("^rule%s+[\"']?(.-)[\"']?$")
      if rule_name then
        table.insert(symbols, {
          name = rule_name,
          type = "rule",
          lnum = i,
          line = line,
        })
      end

      -- Declare symbol (supports declare [trait|enum|window|entry-point] Name)
      local declare_rest = trimmed:match("^declare%s+(.+)$")
      if declare_rest then
        local declare_name = declare_rest:gsub("^(trait)%s+", "")
          :gsub("^(enum)%s+", "")
          :gsub("^(window)%s+", "")
          :gsub("^(entry%-point)%s+", "")
          :match("^[\"']?([%w_%.]+)[\"']?")
        if declare_name then
          table.insert(symbols, {
            name = declare_name,
            type = "declare",
            lnum = i,
            line = line,
          })
        end
      end

      -- Query symbol
      local query_name = trimmed:match("^query%s+[\"']?(.-)[\"']?%s*%(") or trimmed:match("^query%s+[\"']?(.-)[\"']?$")
      if query_name then
        table.insert(symbols, {
          name = query_name,
          type = "query",
          lnum = i,
          line = line,
        })
      end

      -- Function symbol (supports typed, generic, array, or untyped functions)
      local func_name = trimmed:match("^function%s+.-%s+([%w_]+)%s*%(") or trimmed:match("^function%s+([%w_]+)%s*%(")
      if func_name then
        table.insert(symbols, {
          name = func_name,
          type = "function",
          lnum = i,
          line = line,
        })
      end
    end
  end

  return symbols
end

--- Show buffer symbols in quickfix / location list
---@param bufnr number Buffer number
function M.show_symbols(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local symbols = M.get_symbols(bufnr)

  if #symbols == 0 then
    vim.notify("No Drools symbols found in current buffer", vim.log.levels.INFO)
    return
  end

  local qf_items = {}
  for _, sym in ipairs(symbols) do
    table.insert(qf_items, {
      bufnr = bufnr,
      lnum = sym.lnum,
      col = 1,
      text = string.format("[%s] %s", sym.type:upper(), sym.name),
    })
  end

  vim.fn.setloclist(0, qf_items, "r")
  vim.fn.setloclist(0, {}, "a", { title = "Drools Symbols" })
  vim.cmd("lopen")
end

--- Jump to definition of word under cursor (Fact type declare, variable binding, global, query, function, or import)
function M.goto_definition()
  local cword = vim.fn.expand("<cword>")
  if not cword or cword == "" then
    return
  end

  local clean_word = cword:gsub("^%$", "")
  local bufnr = vim.api.nvim_get_current_buf()
  local lines_tbl = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Try local AST-based definition lookup first
  for i, line in ipairs(lines_tbl) do
    if line:match("^%s*declare%s+" .. clean_word)
       or line:match("^%s*import%s+.-" .. clean_word .. "%s*;")
       or line:match("^%s*global%s+.-" .. clean_word)
       or line:match("^%s*query%s+.-" .. clean_word)
       or line:match("^%s*function%s+.-" .. clean_word)
       or line:match("%$" .. clean_word .. "%s*:") then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      vim.cmd("normal! zz")
      return
    end
  end

  -- Fallback: delegate to LSP if active
  local active_clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #active_clients > 0 then
    vim.lsp.buf.definition()
    return
  end

  vim.notify("No definition found for '" .. cword .. "'", vim.log.levels.INFO)
end

--- Jump to specific rule by name
---@param rule_name string Rule name
function M.goto_rule(rule_name)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    local match = line:match("^%s*rule%s+[\"']?(.-)[\"']?$")
    if match and match:lower() == rule_name:lower() then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end

  vim.notify(string.format("Rule '%s' not found", rule_name), vim.log.levels.WARN)
end

return M
