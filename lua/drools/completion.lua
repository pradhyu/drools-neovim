-- lua/drools/completion.lua
-- Context-aware omni-completion provider for Drools Rule Language

local M = {}

local DRL_KEYWORDS = {
  "package", "import", "global", "declare", "query", "function", "rule", "when", "then", "end", "unit", "extends",
  "salience", "agenda-group", "ruleflow-group", "activation-group", "lock-on-active", "no-loop", "auto-focus",
  "enabled", "dialect", "duration", "timer", "calendars", "date-effective", "date-expires", "refract", "direct",
  "and", "or", "not", "exists", "forall", "eval", "from", "over", "entry-point", "accumulate", "collect",
  "matches", "contains", "memberOf", "soundslike", "in", "excludes",
  "after", "before", "coincides", "during", "finishes", "finishedby", "meets", "metby", "overlaps", "overlappedby", "starts", "startedby",
  "sum", "avg", "min", "max", "count", "collectList", "collectSet", "collectArray",
  "init", "action", "reverse", "result",
  "insert", "insertLogical", "modify", "update", "retract", "delete",
  "drools", "kcontext", "entryPoints", "channels",
}

--- Omni-completion function for Neovim (vim.bo.omnifunc)
---@param findstart number 1 to find start col, 0 to return completions
---@param base string Base word to complete
---@return number|table Column index or array of completion items
function M.complete(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    while col > 0 and line:sub(col, col):match("[%w_%.%-%@%$]") do
      col = col - 1
    end
    return col
  else
    local items = {}
    local seen = {}
    local is_var_completion = base:sub(1, 1) == "$"

    -- 1. Add DRL Keywords, attributes, and built-ins
    if not is_var_completion then
      for _, kw in ipairs(DRL_KEYWORDS) do
        if kw:sub(1, #base):lower() == base:lower() then
          seen[kw] = true
          table.insert(items, {
            word = kw,
            menu = "[Drools]",
            kind = "Keyword",
          })
        end
      end
    end

    -- 2. Add Declared Fact Types in buffer
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for _, line in ipairs(lines) do
      if not is_var_completion then
        local declare_type = line:match("^%s*declare%s+([%w_]+)")
        if declare_type and not seen[declare_type] and vim.startswith(declare_type:lower(), base:lower()) then
          seen[declare_type] = true
          table.insert(items, {
            word = declare_type,
            menu = "[Fact]",
            kind = "Class",
          })
        end
      end

      local var, ftype = line:match("%$([%w_]+)%s*:%s*([A-Z][%w_]*)")
      if var and ftype then
        local bound_var = "$" .. var
        if not seen[bound_var] and vim.startswith(bound_var:lower(), base:lower()) then
          seen[bound_var] = true
          table.insert(items, {
            word = bound_var,
            menu = "[" .. ftype .. "]",
            kind = "Variable",
          })
        end
      end
    end

    return items
  end
end

--- Register omnifunc for Drools buffers
function M.setup()
  local group = vim.api.nvim_create_augroup("DroolsCompletion", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "drools", "dsl" },
    callback = function(args)
      vim.bo[args.buf].omnifunc = "v:lua.require'drools.completion'.complete"
    end,
  })
end

return M
