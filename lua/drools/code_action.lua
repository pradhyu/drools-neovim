-- lua/drools/code_action.lua
-- Quick-fix code actions for Drools Rule Language

local M = {}

--- Auto-insert missing 'end' statement at cursor position
function M.fix_missing_end()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]
  vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { "end" })
  vim.notify("Auto-inserted missing 'end' statement", vim.log.levels.INFO)
end

--- Auto-add 'no-loop true' attribute to rule at cursor
function M.add_no_loop()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  -- Find parent rule header line
  for i = cur_line, 1, -1 do
    if lines[i]:match("^%s*rule%s+") then
      vim.api.nvim_buf_set_lines(bufnr, i, i, false, { "    no-loop true" })
      vim.notify("Added 'no-loop true' attribute to rule", vim.log.levels.INFO)
      return
    end
  end
end

--- Auto-generate missing package declaration
function M.add_package()
  local bufnr = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local pkg = "com.example.rules"

  if fname and fname ~= "" then
    local path = vim.fn.fnamemodify(fname, ":h")
    local match = path:match("src/main/resources/(.+)$") or path:match("src/main/rules/(.+)$") or path:match("src/(.+)$")
    if match then
      pkg = match:gsub("/", ".")
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { string.format("package %s;", pkg), "" })
  vim.notify(string.format("Auto-added package declaration: package %s;", pkg), vim.log.levels.INFO)
end

--- Toggle rule enabled state (enabled true / enabled false)
function M.toggle_enabled()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  for i = cur_line, 1, -1 do
    if lines[i]:match("^%s*rule%s+") then
      -- Search attributes in lines below rule header
      for j = i + 1, #lines do
        if lines[j]:match("^%s*when$") or lines[j]:match("^%s*rule%s+") then
          -- Insert enabled false before when
          vim.api.nvim_buf_set_lines(bufnr, j - 1, j - 1, false, { "    enabled false" })
          vim.notify("Set rule attribute: enabled false", vim.log.levels.INFO)
          return
        elseif lines[j]:match("enabled%s+false") then
          lines[j] = lines[j]:gsub("enabled%s+false", "enabled true")
          vim.api.nvim_buf_set_lines(bufnr, j - 1, j, false, { lines[j] })
          vim.notify("Set rule attribute: enabled true", vim.log.levels.INFO)
          return
        elseif lines[j]:match("enabled%s+true") then
          lines[j] = lines[j]:gsub("enabled%s+true", "enabled false")
          vim.api.nvim_buf_set_lines(bufnr, j - 1, j, false, { lines[j] })
          vim.notify("Set rule attribute: enabled false", vim.log.levels.INFO)
          return
        end
      end
    end
  end
end

--- Interactive quick-fix menu prompt
---@param action_idx number|string|nil Optional direct action index
function M.show_quick_fixes(action_idx)
  if action_idx then
    local idx = tonumber(action_idx)
    if idx == 1 then
      M.fix_missing_end()
    elseif idx == 2 then
      M.add_no_loop()
    elseif idx == 3 then
      M.add_package()
    elseif idx == 4 then
      M.toggle_enabled()
    end
    return
  end

  local options = {
    "1. Fix missing 'end' statement",
    "2. Add 'no-loop true' attribute to current rule",
    "3. Auto-insert package declaration",
    "4. Toggle rule execution (enabled true/false)",
  }

  vim.ui.select(options, { prompt = "Drools Quick Fix Actions:" }, function(choice, idx)
    if idx == 1 then
      M.fix_missing_end()
    elseif idx == 2 then
      M.add_no_loop()
    elseif idx == 3 then
      M.add_package()
    elseif idx == 4 then
      M.toggle_enabled()
    end
  end)
end

return M
