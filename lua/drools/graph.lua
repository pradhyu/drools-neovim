-- lua/drools/graph.lua
-- Fact-Rule Dependency Graph & Mermaid Flowchart Diagram Generator for Drools

local M = {}

--- Sanitize string for valid Mermaid node identifiers
local function sanitize_id(str)
  local clean = str:gsub("[^%w_]", "_"):gsub("^%d+", "r_%1")
  return clean ~= "" and clean or "rule_node"
end

--- Analyze facts inserted/modified/retracted in RHS vs matched in LHS across rules
---@param bufnr number Buffer number
---@return table rules Array of rule objects
---@return table chains Array of dependency edges { from, to, trigger, action }
function M.build_dependency_graph(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local rules = {}
  local current_rule = nil
  local section = nil

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
          id = sanitize_id(rule_name),
          salience = 0,
          agenda_group = "MAIN",
          var_to_type = {}, -- map of $var -> FactType
          lhs_facts = {},  -- set of FactTypes matched in LHS
          rhs_modifies = {}, -- list of FactTypes modified in RHS
          rhs_inserts = {},  -- list of FactTypes inserted in RHS
          rhs_deletes = {},  -- list of FactTypes deleted in RHS
          lnum = i,
        }
        section = "HEADER"
      elseif current_rule then
        if trimmed:match("^salience%s+([%-%d]+)") then
          current_rule.salience = tonumber(trimmed:match("^salience%s+([%-%d]+)")) or 0
        end

        if trimmed:match("^agenda%-group%s+[\"']?(.-)[\"']?$") then
          current_rule.agenda_group = trimmed:match("^agenda%-group%s+[\"']?(.-)[\"']?$")
        end

        if trimmed == "when" then
          section = "WHEN"
        elseif trimmed == "then" then
          section = "THEN"
        elseif trimmed == "end" then
          table.insert(rules, current_rule)
          current_rule = nil
          section = nil
        elseif section == "WHEN" then
          -- Match $var : FactType(...)
          for var, ftype in trimmed:gmatch("%$([%w_]+)%s*:%s*([A-Z][%w_]*)") do
            current_rule.var_to_type[var] = ftype
            current_rule.lhs_facts[ftype] = true
          end
          -- Match FactType(...) directly
          for ftype in trimmed:gmatch("([A-Z][%w_]*)%s*%(") do
            current_rule.lhs_facts[ftype] = true
          end
        elseif section == "THEN" then
          -- Match modify($var) or update($var)
          for var in trimmed:gmatch("modify%s*%(%s*%$?([%w_]+)%s*%)") do
            local ftype = current_rule.var_to_type[var] or var
            table.insert(current_rule.rhs_modifies, ftype)
          end

          -- Match insert(new FactType(...)) or insertLogical(new FactType(...))
          for ftype in trimmed:gmatch("insert%a*%s*%(%s*new%s+([A-Z][%w_]*)") do
            table.insert(current_rule.rhs_inserts, ftype)
          end

          -- Match delete($var) or retract($var)
          for var in trimmed:gmatch("delete%s*%(%s*%$?([%w_]+)%s*%)") do
            local ftype = current_rule.var_to_type[var] or var
            table.insert(current_rule.rhs_deletes, ftype)
          end
          for var in trimmed:gmatch("retract%s*%(%s*%$?([%w_]+)%s*%)") do
            local ftype = current_rule.var_to_type[var] or var
            table.insert(current_rule.rhs_deletes, ftype)
          end
        end
      end
    end
  end

  if current_rule then
    table.insert(rules, current_rule)
  end

  -- Build activation edges
  local edges = {}
  for _, r1 in ipairs(rules) do
    -- Inserts -> trigger LHS match in r2
    for _, ins_type in ipairs(r1.rhs_inserts) do
      for _, r2 in ipairs(rules) do
        if r1.name ~= r2.name and r2.lhs_facts[ins_type] then
          table.insert(edges, { from = r1, to = r2, trigger = ins_type, action = "inserts" })
        end
      end
    end

    -- Modifies -> trigger LHS re-evaluation in r2
    for _, mod_type in ipairs(r1.rhs_modifies) do
      for _, r2 in ipairs(rules) do
        if r1.name ~= r2.name and r2.lhs_facts[mod_type] then
          table.insert(edges, { from = r1, to = r2, trigger = mod_type, action = "modifies" })
        end
      end
    end
  end

  return rules, edges
end

--- Generate Mermaid markdown string for the current buffer's rule chaining
---@param bufnr number|nil Buffer handle
---@return string[] Array of markdown lines
function M.generate_mermaid(bufnr)
  local rules, edges = M.build_dependency_graph(bufnr)

  local lines = {
    "```mermaid",
    "flowchart TD",
    "  %% Drools Rule Chaining & Fact Activation Graph",
  }

  if #rules == 0 then
    table.insert(lines, "  %% No rules found in current buffer")
    table.insert(lines, "```")
    return lines
  end

  -- Group rules by agenda group
  local groups = {}
  for _, r in ipairs(rules) do
    groups[r.agenda_group] = groups[r.agenda_group] or {}
    table.insert(groups[r.agenda_group], r)
  end

  for gname, grules in pairs(groups) do
    if gname ~= "MAIN" then
      table.insert(lines, string.format("  subgraph %s[\"Agenda Group: %s\"]", sanitize_id(gname), gname))
    end
    for _, r in ipairs(grules) do
      table.insert(lines, string.format("    %s[\"Rule: %s<br/>salience: %d\"]", r.id, r.name, r.salience))
    end
    if gname ~= "MAIN" then
      table.insert(lines, "  end")
    end
  end

  if #edges == 0 then
    table.insert(lines, "  %% No direct inter-rule activation triggers detected")
  else
    for _, e in ipairs(edges) do
      if e.action == "inserts" then
        table.insert(lines, string.format("  %s -->|\"inserts %s\"| %s", e.from.id, e.trigger, e.to.id))
      elseif e.action == "modifies" then
        table.insert(lines, string.format("  %s -.->|\"modifies %s\"| %s", e.from.id, e.trigger, e.to.id))
      end
    end
  end

  table.insert(lines, "```")
  return lines
end

--- Display preview window and copy Mermaid diagram to clipboard / split
function M.show_mermaid_split()
  local bufnr = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local base_name = fname ~= "" and vim.fn.fnamemodify(fname, ":t:r") or "drools_rules"

  local mmd_lines = M.generate_mermaid(bufnr)
  table.insert(mmd_lines, 1, string.format("# Mermaid Rule Chaining Diagram: `%s`", base_name))
  table.insert(mmd_lines, 2, "")

  -- Open in new split buffer
  vim.cmd("vnew")
  local new_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, mmd_lines)
  vim.bo[new_buf].filetype = "markdown"
  vim.bo[new_buf].buftype = "nofile"
  vim.api.nvim_buf_set_name(new_buf, base_name .. "_chaining.mmd.md")

  -- Copy mermaid code block to register '+' if available
  local code_only = {}
  for i = 4, #mmd_lines - 1 do
    table.insert(code_only, mmd_lines[i])
  end
  pcall(vim.fn.setreg, "+", table.concat(code_only, "\n"))
  pcall(vim.fn.setreg, '"', table.concat(code_only, "\n"))

  vim.notify("Generated Mermaid rule chaining diagram! (Code copied to clipboard)", vim.log.levels.INFO)
end

--- Legacy show graph alias
function M.show_graph()
  M.show_mermaid_split()
end

return M
