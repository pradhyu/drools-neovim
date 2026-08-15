-- lua/drools/highlight.lua
-- Visual section highlighting for Drools files (distinguishes when vs then blocks)

local M = {}

local ns_id = vim.api.nvim_create_namespace("drools_section_hl")

--- Setup custom highlight groups for Drools sections
function M.setup_highlight_groups()
  -- Default highlight groups with fallback colors compatible with light & dark themes
  local hl = vim.api.nvim_set_hl

  -- Rule header line highlight
  hl(0, "DroolsRuleHeaderLine", { default = true, bg = "#1e293b", bold = true })

  -- LHS 'when' condition block line highlight (subtle blue/cyan tint)
  hl(0, "DroolsWhenLine", { default = true, bg = "#0f172a" })
  hl(0, "DroolsWhenKeyword", { default = true, fg = "#38bdf8", bold = true })

  -- RHS 'then' action block line highlight (subtle emerald/green tint)
  hl(0, "DroolsThenLine", { default = true, bg = "#062c1d" })
  hl(0, "DroolsThenKeyword", { default = true, fg = "#34d399", bold = true })
end

--- Apply section background & keyword highlights to a buffer
---@param bufnr number|nil Buffer handle
function M.highlight_sections(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "drools" then
    return
  end

  M.setup_highlight_groups()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_section = nil -- "rule", "when", "then"

  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$") or ""

    if trimmed:match("^rule%s+") then
      current_section = "rule"
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        line_hl_group = "DroolsRuleHeaderLine",
        priority = 100,
      })
    elseif trimmed == "when" then
      current_section = "when"
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        line_hl_group = "DroolsWhenLine",
        priority = 90,
      })
    elseif trimmed == "then" then
      current_section = "then"
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        line_hl_group = "DroolsThenLine",
        priority = 90,
      })
    elseif trimmed == "end" then
      current_section = nil
    elseif current_section == "when" then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        line_hl_group = "DroolsWhenLine",
        priority = 80,
      })
    elseif current_section == "then" then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        line_hl_group = "DroolsThenLine",
        priority = 80,
      })
    end
  end
end

--- Clear section highlights from buffer
---@param bufnr number|nil Buffer handle
function M.clear_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

--- Toggle section highlights on/off
---@param bufnr number|nil Buffer handle
function M.toggle_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
  if #marks > 0 then
    M.clear_highlights(bufnr)
    vim.notify("Drools section background highlights: DISABLED", vim.log.levels.INFO)
  else
    M.highlight_sections(bufnr)
    vim.notify("Drools section background highlights: ENABLED (LHS 'when' vs RHS 'then')", vim.log.levels.INFO)
  end
end

--- Attach automatic section highlighting to buffer events
---@param opts table Options
function M.setup(opts)
  M.setup_highlight_groups()
  local group = vim.api.nvim_create_augroup("DroolsSectionHighlight", { clear = true })

  -- Highlight open Drools buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "drools" then
      M.highlight_sections(buf)
    end
  end

  -- Auto-highlight on FileType, BufEnter, BufReadPost, TextChanged, InsertLeave
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufReadPost", "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.bo[args.buf].filetype == "drools" then
        M.highlight_sections(args.buf)
      end
    end,
  })
end

return M
