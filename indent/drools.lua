-- indent/drools.lua
-- Indentation rules for Drools Rule Language (.drl)

local function get_prev_nonblank(lnum)
  local prev = vim.fn.prevnonblank(lnum - 1)
  if prev > 0 then
    return prev, vim.fn.getline(prev)
  end
  return 0, ""
end

function _G.drools_indent()
  local lnum = vim.v.lnum
  if lnum == 1 then
    return 0
  end

  local cur_line = vim.fn.getline(lnum)
  local prev_lnum, prev_line = get_prev_nonblank(lnum)
  if prev_lnum == 0 then
    return 0
  end

  local prev_indent = vim.fn.indent(prev_lnum)
  local sw = vim.fn.shiftwidth()

  -- Check if previous line opened a block
  local opens_block = prev_line:match("^%s*rule%s")
    or prev_line:match("^%s*when%s*$")
    or prev_line:match("^%s*then%s*$")
    or prev_line:match("^%s*declare%s")
    or prev_line:match("^%s*query%s")
    or prev_line:match("^%s*function%s")

  local new_indent = prev_indent
  if opens_block then
    new_indent = prev_indent + sw
  end

  -- Check if current line closes or transitions a section
  if cur_line:match("^%s*when%s*$") or cur_line:match("^%s*then%s*$") or cur_line:match("^%s*end%s*$") then
    new_indent = math.max(0, new_indent - sw)
  end

  return new_indent
end

vim.bo.indentexpr = "v:lua.drools_indent()"
vim.bo.indentkeys = "0=when,0=then,0=end,0=rule,0=declare,0=query,0=function,o,O,0#,!^F"
