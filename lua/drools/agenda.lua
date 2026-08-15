-- lua/drools/agenda.lua
-- Rule Agenda & Priority Inspector for Drools Rule Engine

local M = {}

--- Extract all rules with salience, agenda-group, and infinite loop warnings
---@param bufnr number Buffer number
---@return table List of rule objects { name, salience, agenda_group, lnum, warnings }
function M.analyze_agenda(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local rules = {}

  local current_rule = nil
  local rule_start_line = 0

  for i, line in ipairs(lines) do
    local trimmed = line:gsub("//.*$", ""):match("^%s*(.-)%s*$")
    if trimmed then
      local rule_name = trimmed:match("^rule%s+[\"']?(.-)[\"']?$")
      if rule_name then
        if current_rule then
          table.insert(rules, current_rule)
        end
        current_rule = {
          name = rule_name,
          salience = 0,
          agenda_group = "MAIN",
          no_loop = false,
          lock_on_active = false,
          has_modify = false,
          lnum = i,
          lines = {},
        }
      elseif current_rule then
        table.insert(current_rule.lines, trimmed)

        local sal = trimmed:match("^salience%s+([%-%d]+)")
        if sal then
          current_rule.salience = tonumber(sal) or 0
        end

        local group = trimmed:match("^agenda%-group%s+[\"']?(.-)[\"']?$")
        if group then
          current_rule.agenda_group = group
        end

        if trimmed:match("^no%-loop%s+true") then
          current_rule.no_loop = true
        end

        if trimmed:match("^lock%-on%-active%s+true") then
          current_rule.lock_on_active = true
        end

        if trimmed:match("modify%s*%(") or trimmed:match("update%s*%(") then
          current_rule.has_modify = true
        end

        if trimmed == "end" then
          table.insert(rules, current_rule)
          current_rule = nil
        end
      end
    end
  end

  if current_rule then
    table.insert(rules, current_rule)
  end

  -- Calculate warnings for each rule
  for _, r in ipairs(rules) do
    r.warnings = {}
    if r.has_modify and not r.no_loop and not r.lock_on_active then
      table.insert(r.warnings, "⚠️ Potential infinite loop risk: modifies facts without 'no-loop' or 'lock-on-active'")
    end
  end

  -- Sort rules by agenda_group then descending salience
  table.sort(rules, function(a, b)
    if a.agenda_group ~= b.agenda_group then
      return a.agenda_group < b.agenda_group
    end
    return a.salience > b.salience
  end)

  return rules
end

--- Display floating Agenda Inspector window
function M.show_agenda()
  local bufnr = vim.api.nvim_get_current_buf()
  local rules = M.analyze_agenda(bufnr)

  if #rules == 0 then
    vim.notify("No rules found in current buffer to build Agenda", vim.log.levels.INFO)
    return
  end

  local display_lines = {
    "# 📊 Drools Rule Agenda & Execution Order",
    "",
    "Rules are grouped by `agenda-group` and sorted by descending `salience` priority.",
    "",
  }

  local current_group = nil
  for _, r in ipairs(rules) do
    if r.agenda_group ~= current_group then
      current_group = r.agenda_group
      table.insert(display_lines, string.format("## Agenda Group: `%s`", current_group))
      table.insert(display_lines, "")
    end

    local status = string.format("  • **\"%s\"** (Salience: `%d`, Line: `%d`)", r.name, r.salience, r.lnum)
    table.insert(display_lines, status)

    for _, w in ipairs(r.warnings) do
      table.insert(display_lines, string.format("      %s", w))
    end
  end

  local popup_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, display_lines)
  vim.bo[popup_buf].filetype = "markdown"
  vim.bo[popup_buf].bufhidden = "wipe"

  local width = 80
  local height = math.min(#display_lines + 2, 22)

  local win_opts = {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Drools Agenda Inspector ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(popup_buf, true, win_opts)

  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "<Esc>", close, { buffer = popup_buf, silent = true })
  vim.keymap.set("n", "q", close, { buffer = popup_buf, silent = true })
end

return M
