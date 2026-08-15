-- lua/drools/textobjects.lua
-- Custom text-objects and structural motions for Drools Rule Language

local M = {}

--- Select range in buffer
---@param start_line number 1-indexed line
---@param end_line number 1-indexed line
local function select_range(start_line, end_line)
  vim.cmd("normal! \27") -- Exit visual mode first
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal! V")
  vim.api.nvim_win_set_cursor(0, { end_line, 0 })
end

--- Select block enclosing current cursor position
---@param block_type "rule"|"when"|"then"|"declare" Type of block
---@param inner boolean If true, exclude boundary keywords (when/then/end)
function M.select_block(block_type, inner)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]

  if block_type == "rule" then
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
      if inner then
        select_range(start_lnum + 1, end_lnum - 1)
      else
        select_range(start_lnum, end_lnum)
      end
    end

  elseif block_type == "when" then
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
      if inner then
        select_range(when_lnum + 1, then_lnum - 1)
      else
        select_range(when_lnum, then_lnum - 1)
      end
    end

  elseif block_type == "then" then
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
      if inner then
        select_range(then_lnum + 1, end_lnum - 1)
      else
        select_range(then_lnum, end_lnum)
      end
    end

  elseif block_type == "declare" then
    local declare_lnum, end_lnum = nil, nil
    for i = cur_line, 1, -1 do
      if lines[i]:match("^%s*declare%s+") then
        declare_lnum = i
        break
      end
    end
    for i = cur_line, #lines do
      if lines[i]:match("^%s*end%s*$") then
        end_lnum = i
        break
      end
    end
    if declare_lnum and end_lnum then
      if inner then
        select_range(declare_lnum + 1, end_lnum - 1)
      else
        select_range(declare_lnum, end_lnum)
      end
    end
  end
end

--- Register buffer text-object keymaps
function M.setup()
  local group = vim.api.nvim_create_augroup("DroolsTextobjects", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "drools", "dsl" },
    callback = function(args)
      local opts = { buffer = args.buf, silent = true }

      -- Around / Inside Rule (aR / iR)
      vim.keymap.set({ "o", "x" }, "aR", function() M.select_block("rule", false) end, vim.tbl_extend("force", opts, { desc = "Around Rule block" }))
      vim.keymap.set({ "o", "x" }, "iR", function() M.select_block("rule", true) end, vim.tbl_extend("force", opts, { desc = "Inside Rule block" }))

      -- Around / Inside When clause (aW / iW)
      vim.keymap.set({ "o", "x" }, "aW", function() M.select_block("when", false) end, vim.tbl_extend("force", opts, { desc = "Around When clause" }))
      vim.keymap.set({ "o", "x" }, "iW", function() M.select_block("when", true) end, vim.tbl_extend("force", opts, { desc = "Inside When clause" }))

      -- Around / Inside Then clause (aT / iT)
      vim.keymap.set({ "o", "x" }, "aT", function() M.select_block("then", false) end, vim.tbl_extend("force", opts, { desc = "Around Then clause" }))
      vim.keymap.set({ "o", "x" }, "iT", function() M.select_block("then", true) end, vim.tbl_extend("force", opts, { desc = "Inside Then clause" }))

      -- Around / Inside Declare block (aD / iD)
      vim.keymap.set({ "o", "x" }, "aD", function() M.select_block("declare", false) end, vim.tbl_extend("force", opts, { desc = "Around Declare block" }))
      vim.keymap.set({ "o", "x" }, "iD", function() M.select_block("declare", true) end, vim.tbl_extend("force", opts, { desc = "Inside Declare block" }))
    end,
  })
end

return M
