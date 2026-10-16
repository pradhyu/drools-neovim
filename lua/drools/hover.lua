-- lua/drools/hover.lua
-- Documentation hover and mouse interaction engine for Drools Rule Language

local M = {}

local docs_cache = nil
M.current_hover_win = nil
M.current_hover_buf = nil

--- Load Drools Specification Reference JSON
---@return table Map of keyword to doc objects
function M.get_spec_docs()
  if docs_cache then
    return docs_cache
  end

  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local json_path = plugin_dir .. "/resources/drools_spec_docs.json"

  local f = io.open(json_path, "r")
  if not f then
    docs_cache = {}
    return docs_cache
  end

  local content = f:read("*a")
  f:close()

  local ok, parsed = pcall(vim.json.decode, content)
  if ok and parsed then
    docs_cache = parsed
  else
    docs_cache = {}
  end

  return docs_cache
end

--- Close any active hover window safely
function M.close_hover()
  if M.current_hover_win and vim.api.nvim_win_is_valid(M.current_hover_win) then
    pcall(vim.api.nvim_win_close, M.current_hover_win, true)
  end
  M.current_hover_win = nil
  M.current_hover_buf = nil
end

local function append_multiline(target, str)
  if type(str) == "string" then
    for line in str:gmatch("[^\r\n]+") do
      table.insert(target, line)
    end
  end
end

--- Render markdown lines in a styled floating popup window
---@param lines string[] Array of text lines
---@param title string Window title
---@param relative_to? string "cursor" (default) or "mouse"
---@return number|nil Window ID
function M.show_popup(lines, title, relative_to)
  relative_to = relative_to or "cursor"

  -- If hover popup is already open, pressing K again enters the popup window
  if M.current_hover_win and vim.api.nvim_win_is_valid(M.current_hover_win) then
    if relative_to == "cursor" then
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win ~= M.current_hover_win then
        vim.api.nvim_set_current_win(M.current_hover_win)
        return M.current_hover_win
      end
    end
    M.close_hover()
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"

  local max_line_len = 0
  for _, line in ipairs(lines) do
    max_line_len = math.max(max_line_len, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(math.max(max_line_len + 4, 36), math.max(40, vim.o.columns - 6))
  local height = math.min(#lines, math.max(10, vim.o.lines - 6))

  local win_opts = {
    relative = relative_to == "mouse" and "mouse" or "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title and string.format(" Drools: %s ", title) or " Drools Hover ",
    title_pos = "center",
  }

  local ok, win = pcall(vim.api.nvim_open_win, buf, false, win_opts)
  if not ok or not win then
    return nil
  end

  vim.wo[win].winblend = 5
  vim.wo[win].conceallevel = 2
  M.current_hover_win = win
  M.current_hover_buf = buf

  local current_buf = vim.api.nvim_get_current_buf()

  -- Popup buffer keymaps: pressing 'q' or '<Esc>' closes popup
  local close_action = function()
    M.close_hover()
  end
  pcall(vim.keymap.set, "n", "q", close_action, { buffer = buf, silent = true, nowait = true })
  pcall(vim.keymap.set, "n", "<Esc>", close_action, { buffer = buf, silent = true, nowait = true })

  -- Main buffer autocmds: close on cursor movement, buffer switch, or editing
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "InsertEnter" }, {
    buffer = current_buf,
    once = true,
    callback = function()
      M.close_hover()
    end,
  })

  return win
end

--- Get current word under cursor including hyphens and @ symbols
---@param line_str? string Optional line content
---@param col_idx? number Optional 1-indexed column
---@return string Extracted word
function M.get_word_under_cursor(line_str, col_idx)
  local line = line_str or vim.api.nvim_get_current_line()
  local col = col_idx or (vim.api.nvim_win_get_cursor(0)[2] + 1)

  local start_pos = col
  while start_pos > 1 and line:sub(start_pos - 1, start_pos - 1):match("[%w%_%-%@%$]") do
    start_pos = start_pos - 1
  end
  local end_pos = col
  while end_pos <= #line and line:sub(end_pos, end_pos):match("[%w%_%-%@%$]") do
    end_pos = end_pos + 1
  end

  local line_word = line:sub(start_pos, end_pos - 1)
  if line_word and line_word ~= "" then
    return line_word
  end

  return vim.fn.expand("<cWORD>")
end

--- Show specification document popup for a specific keyword name
---@param keyword string Keyword name
---@param relative_to? string "cursor" or "mouse"
---@return boolean True if documentation was found and shown
function M.show_spec_doc(keyword, relative_to)
  if not keyword or keyword == "" then
    return false
  end

  local docs = M.get_spec_docs()
  local keyword_info = docs[keyword] or docs[keyword:lower()] or docs["@" .. keyword:lower()]

  if keyword_info then
    local markdown_lines = {
      string.format("### `%s` *(%s)*", keyword_info.name, keyword_info.category),
      "",
    }
    append_multiline(markdown_lines, keyword_info.description)
    table.insert(markdown_lines, "")
    table.insert(markdown_lines, "**Syntax:**")
    table.insert(markdown_lines, "```drools")
    append_multiline(markdown_lines, keyword_info.syntax)
    table.insert(markdown_lines, "```")

    if keyword_info.example then
      table.insert(markdown_lines, "")
      table.insert(markdown_lines, "**Example:**")
      table.insert(markdown_lines, "```drools")
      append_multiline(markdown_lines, keyword_info.example)
      table.insert(markdown_lines, "```")
    end

    M.show_popup(markdown_lines, keyword_info.name, relative_to)
    return true
  end

  return false
end

--- Show documentation hover for symbol under cursor or mouse position
---@param relative_to? string "cursor" or "mouse"
function M.show_hover(relative_to)
  local cword = M.get_word_under_cursor()
  if not cword or cword == "" then
    return
  end

  -- 1. Check official Drools Specification Reference DB
  if M.show_spec_doc(cword, relative_to) then
    return
  end

  -- Fallback check with simple cword
  local simple_cword = vim.fn.expand("<cword>")
  if simple_cword ~= cword and M.show_spec_doc(simple_cword, relative_to) then
    return
  end

  -- 2. Check active LSP client
  local active_clients = vim.lsp.get_clients({ bufnr = 0 })
  if #active_clients > 0 then
    vim.lsp.buf.hover()
    return
  end

  -- 3. In-buffer Symbol & AST Definition Lookup
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local clean_word = cword:gsub("^%$", "")

  for i, line in ipairs(lines) do
    -- Fact type declaration block (extract full declare ... end block)
    if line:match("^%s*declare%s+.-" .. clean_word) then
      local decl_lines = { line }
      for j = i + 1, math.min(#lines, i + 25) do
        table.insert(decl_lines, lines[j])
        if lines[j]:match("^%s*end%s*;?$") then
          break
        end
      end
      M.show_popup({
        string.format("### Fact Type Declaration: `%s`", clean_word),
        "",
        string.format("*Declared at line %d:*", i),
        "```drools",
        table.concat(decl_lines, "\n"),
        "```",
      }, clean_word, relative_to)
      return

    -- Rule declaration block
    elseif line:match("^%s*rule%s+[\"']?" .. clean_word .. "[\"']?") then
      M.show_popup({
        string.format("### Rule: `%s`", clean_word),
        "",
        string.format("*Defined at line %d:*", i),
        "```drools",
        line,
        "```",
      }, clean_word, relative_to)
      return

    -- Query declaration
    elseif line:match("^%s*query%s+.-" .. clean_word) then
      M.show_popup({
        string.format("### Query: `%s`", clean_word),
        "",
        string.format("*Defined at line %d:*", i),
        "```drools",
        line,
        "```",
      }, clean_word, relative_to)
      return

    -- Function declaration
    elseif line:match("^%s*function%s+.-" .. clean_word) then
      M.show_popup({
        string.format("### Function: `%s`", clean_word),
        "",
        string.format("*Declared at line %d:*", i),
        "```drools",
        line,
        "```",
      }, clean_word, relative_to)
      return

    -- Global / Application-data variable
    elseif line:match("^%s*global%s+.-" .. clean_word) or line:match("^%s*application%-data%s+.-" .. clean_word) then
      M.show_popup({
        string.format("### Global Variable: `%s`", clean_word),
        "",
        string.format("*Declared at line %d:*", i),
        "```drools",
        line,
        "```",
      }, clean_word, relative_to)
      return

    -- Variable binding ($var: Fact(...) or $var := ... or $var => ...)
    elseif line:match("%$" .. clean_word .. "%s*:")
        or line:match("%$" .. clean_word .. "%s*:=")
        or line:match("%$" .. clean_word .. "%s*=>") then
      M.show_popup({
        string.format("### Bound Variable: `$%s`", clean_word),
        "",
        string.format("*Binding at line %d:*", i),
        "```drools",
        line:match("^%s*(.-)%s*$") or line,
        "```",
      }, "$" .. clean_word, relative_to)
      return
    end
  end

  vim.notify(string.format("No documentation or definition found for '%s'", cword), vim.log.levels.INFO)
end

--- Teardown any mousemove listeners and ensure mousemoveevent is disabled
---@param _ table|nil
function M.setup_mouse(_)
  pcall(function()
    vim.o.mousemoveevent = false
    vim.api.nvim_del_augroup_by_name("DroolsMouseHover")
  end)
end

return M
