-- lua/drools/formatter.lua
-- Code formatter for Drools Rule Language (.drl) files

local M = {}

--- Format the given buffer
---@param bufnr number Buffer number
function M.format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local formatted = {}
  local indent_level = 0
  local sw = "    " -- 4 spaces

  for _, line in ipairs(lines) do
    local trimmed = line:gsub("%s+$", ""):match("^%s*(.-)$") or ""

    if trimmed == "" then
      table.insert(formatted, "")
    else
      -- Check if line decreases indent
      if trimmed:match("^when$") or trimmed:match("^then$") or trimmed:match("^end$") then
        indent_level = math.max(0, indent_level - 1)
      end

      local current_indent = string.rep(sw, indent_level)
      table.insert(formatted, current_indent .. trimmed)

      -- Check if line increases indent for subsequent lines
      if trimmed:match("^rule%s") or trimmed:match("^when$") or trimmed:match("^then$") or trimmed:match("^declare%s") or trimmed:match("^query%s") then
        indent_level = indent_level + 1
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
  vim.notify("Formatted Drools buffer", vim.log.levels.INFO)
end

return M
