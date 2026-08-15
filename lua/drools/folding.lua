-- lua/drools/folding.lua
-- Structural Folding & Focus Tools for huge Drools rule files

local M = {}

--- Create manual fold between start_line and end_line (1-indexed)
---@param start_line number
---@param end_line number
local function create_fold(start_line, end_line)
  if start_line and end_line and end_line > start_line then
    pcall(function() vim.wo.foldmethod = "manual" end)
    pcall(function() vim.cmd(string.format("%d,%dfold", start_line, end_line)) end)
  end
end

--- Fold enclosing rule at cursor or visual selection
function M.fold_rule()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  local start_lnum, end_lnum = nil, nil
  for i = cur_line, 1, -1 do
    if lines[i]:match("^%s*rule%s+") then
      start_lnum = i
      break
    end
  end
  for i = cur_line, #lines do
    if lines[i]:match("^%s*end%s*$") then
      end_lnum = i
      break
    end
  end

  if start_lnum and end_lnum then
    create_fold(start_lnum, end_lnum)
    vim.notify("Folded rule block", vim.log.levels.INFO)
  end
end

--- Fold 'when' clause of current rule
function M.fold_when()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  local when_lnum, then_lnum = nil, nil
  for i = cur_line, 1, -1 do
    if lines[i]:match("^%s*when%s*$") then
      when_lnum = i
      break
    end
  end
  for i = cur_line, #lines do
    if lines[i]:match("^%s*then%s*$") then
      then_lnum = i
      break
    end
  end

  if when_lnum and then_lnum then
    create_fold(when_lnum + 1, then_lnum - 1)
    vim.notify("Folded 'when' condition block", vim.log.levels.INFO)
  end
end

--- Fold 'then' clause of current rule
function M.fold_then()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  local then_lnum, end_lnum = nil, nil
  for i = cur_line, 1, -1 do
    if lines[i]:match("^%s*then%s*$") then
      then_lnum = i
      break
    end
  end
  for i = cur_line, #lines do
    if lines[i]:match("^%s*end%s*$") then
      end_lnum = i
      break
    end
  end

  if then_lnum and end_lnum then
    create_fold(then_lnum + 1, end_lnum - 1)
    vim.notify("Folded 'then' action block", vim.log.levels.INFO)
  end
end

--- Fold ALL rules across entire file
function M.fold_all_rules()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local rule_start = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*rule%s+") then
      rule_start = i
    elseif line:match("^%s*end%s*$") and rule_start then
      create_fold(rule_start, i)
      rule_start = nil
    end
  end
  vim.notify("Folded all rule blocks in buffer", vim.log.levels.INFO)
end

--- Fold ALL 'when' condition blocks across file
function M.fold_all_when()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local when_start = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*when%s*$") then
      when_start = i
    elseif line:match("^%s*then%s*$") and when_start then
      create_fold(when_start + 1, i - 1)
      when_start = nil
    end
  end
  vim.notify("Folded all 'when' condition blocks in buffer", vim.log.levels.INFO)
end

--- Fold ALL 'then' action blocks across file
function M.fold_all_then()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local then_start = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*then%s*$") then
      then_start = i
    elseif line:match("^%s*end%s*$") and then_start then
      create_fold(then_start + 1, i - 1)
      then_start = nil
    end
  end
  vim.notify("Folded all 'then' action blocks in buffer", vim.log.levels.INFO)
end

--- Fold all rules EXCEPT those matching search pattern (Focus Mode for huge files)
---@param pattern string|nil Filter query
function M.fold_except(pattern)
  if not pattern or pattern == "" then
    pattern = vim.fn.input("Focus on rules matching pattern: ")
  end
  if not pattern or pattern == "" then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- First unfold all
  vim.cmd("normal! zR")

  local rule_start = nil
  local rule_text = {}

  for i, line in ipairs(lines) do
    if line:match("^%s*rule%s+") then
      rule_start = i
      rule_text = { line }
    elseif rule_start then
      table.insert(rule_text, line)
      if line:match("^%s*end%s*$") then
        local full_rule = table.concat(rule_text, "\n")
        if not full_rule:lower():find(pattern:lower(), 1, true) then
          create_fold(rule_start, i)
        end
        rule_start = nil
        rule_text = {}
      end
    end
  end

  vim.notify(string.format("Folded all rules EXCEPT matching '%s'", pattern), vim.log.levels.INFO)
end

--- Unfold all folds in buffer
function M.unfold_all()
  vim.cmd("normal! zR")
  vim.notify("Unfolded all blocks in buffer", vim.log.levels.INFO)
end

--- Pure Lua fold expression for Drools buffers that marks fold start (">1") on rule/declare/query/function headers
---@param lnum number Line index
---@return string Fold level indicator
function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  if not line then return "0" end

  -- Header line: explicit fold level start (>1) -> displays 'v' sign in gutter column
  if line:match("^%s*rule%s+") or line:match("^%s*declare%s+") or line:match("^%s*query%s+") or line:match("^%s*function%s+") then
    return ">1"
  end

  -- End of block line
  if line:match("^%s*end%s*$") then
    return "1"
  end

  -- Check if line is inside a block
  for i = lnum - 1, 1, -1 do
    local prev = vim.fn.getline(i)
    if prev:match("^%s*end%s*$") then
      return "0"
    elseif prev:match("^%s*rule%s+") or prev:match("^%s*declare%s+") or prev:match("^%s*query%s+") or prev:match("^%s*function%s+") then
      return "1"
    end
  end

  return "0"
end

--- Custom fold text representation showing rule name & collapsed line count
function M.fold_text()
  local start_line = vim.fn.getline(vim.v.foldstart)
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  return string.format(" 📂 %s  ... (%d lines collapsed)", start_line:match("^%s*(.-)%s*$") or "", line_count)
end

--- Setup buffer-local fold column gutter display and visual indicators
---@param winid number|nil Window handle
function M.setup_fold_display(winid)
  winid = winid or 0

  pcall(function()
    vim.api.nvim_set_option_value("foldenable", true, { scope = "local", win = winid })
    vim.api.nvim_set_option_value("foldcolumn", "2", { scope = "local", win = winid })
    vim.api.nvim_set_option_value("foldtext", "v:lua.require'drools.folding'.fold_text()", { scope = "local", win = winid })
    vim.api.nvim_set_option_value("foldmethod", "expr", { scope = "local", win = winid })
    vim.api.nvim_set_option_value("foldexpr", "v:lua.require'drools.folding'.foldexpr(v:lnum)", { scope = "local", win = winid })

    vim.opt_local.fillchars:append({
      foldopen = "v",
      foldclose = ">",
      foldsep = "│",
    })
  end)
end

return M
