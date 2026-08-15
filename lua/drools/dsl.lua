-- lua/drools/dsl.lua
-- Domain Specific Language (.dsl) parser and rule expansion previewer for Drools

local M = {}

--- Load .dsl mapping entries from a file or buffer
---@param dsl_bufnr number Buffer handle
---@return table List of { scope, pattern, replacement }
function M.parse_dsl_mappings(dsl_bufnr)
  local lines = vim.api.nvim_buf_get_lines(dsl_bufnr, 0, -1, false)
  local mappings = {}

  for _, line in ipairs(lines) do
    local scope, pattern, replacement = line:match("^%[(%w+)%]%s*(.-)%s*=%s*(.-)%s*$")
    if scope and pattern and replacement then
      table.insert(mappings, {
        scope = scope:lower(),
        pattern = pattern,
        replacement = replacement,
      })
    end
  end

  return mappings
end

--- Expand DSL phrases in a DRL buffer using active DSL mappings
function M.expand_dsl_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find corresponding .dsl file in same directory or project root
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local dsl_file = fname:gsub("%.drl$", ".dsl")

  local mappings = {}
  local f = io.open(dsl_file, "r")
  if f then
    for line in f:lines() do
      local scope, pattern, replacement = line:match("^%[(%w+)%]%s*(.-)%s*=%s*(.-)%s*$")
      if scope and pattern and replacement then
        table.insert(mappings, {
          scope = scope:lower(),
          pattern = pattern,
          replacement = replacement,
        })
      end
    end
    f:close()
  end

  local expanded_lines = {}
  for _, line in ipairs(lines) do
    local result_line = line
    for _, map in ipairs(mappings) do
      -- Simple regex string substitution for DSL expressions
      local lua_pat = map.pattern:gsub("{%w+}", "([^%%s%%,%%)]+)")
      local lua_repl = map.replacement:gsub("{%w+}", "%%1")
      result_line = result_line:gsub(lua_pat, lua_repl)
    end
    table.insert(expanded_lines, result_line)
  end

  -- Open expanded raw DRL in a split preview buffer
  vim.cmd("vnew")
  local new_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, expanded_lines)
  vim.bo[new_buf].filetype = "drools"
  vim.bo[new_buf].buftype = "nofile"
  vim.api.nvim_buf_set_name(new_buf, "Expanded_DSL_Preview.drl")

  vim.notify(string.format("Expanded %d DSL rules into raw DRL!", #expanded_lines), vim.log.levels.INFO)
end

return M
