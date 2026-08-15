-- lua/drools/hover.lua
-- Documentation hover and Ctrl+Click definition lookup engine for Drools

local M = {}

local docs_cache = nil

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

--- Render markdown lines in a styled floating popup window
---@param lines string[] Array of text lines
---@param title string Window title
function M.show_popup(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  width = math.min(math.max(width + 4, 40), 80)
  local height = math.min(#lines, 20)

  local win_opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title and string.format(" Drools Specification: %s ", title) or " Drools Hover ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, false, win_opts)
  vim.wo[win].winblend = 5
  vim.wo[win].conceallevel = 2

  local current_buf = vim.api.nvim_get_current_buf()

  local close_win = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Close on <Esc> or 'q' in main buffer or popup buffer
  local key_opts = { buffer = current_buf, silent = true, nowait = true }
  pcall(vim.keymap.set, "n", "<Esc>", close_win, key_opts)
  pcall(vim.keymap.set, "n", "q", close_win, key_opts)
  pcall(vim.keymap.set, "n", "<Esc>", close_win, { buffer = buf, silent = true, nowait = true })
  pcall(vim.keymap.set, "n", "q", close_win, { buffer = buf, silent = true, nowait = true })

  -- Close on cursor move or buffer leave
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    buffer = current_buf,
    once = true,
    callback = close_win,
  })
end

--- Get current word under cursor including hyphens and @ symbols
function M.get_word_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed column

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

local function append_multiline(target, str)
  if type(str) == "string" then
    for line in str:gmatch("[^\r\n]+") do
      table.insert(target, line)
    end
  end
end

--- Show specification document popup for a specific keyword name
---@param keyword string Keyword name
---@return boolean True if documentation was found and shown
function M.show_spec_doc(keyword)
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

    M.show_popup(markdown_lines, keyword_info.name)
    return true
  end

  return false
end

--- Show documentation hover for symbol under cursor or mouse position
function M.show_hover()
  local cword = M.get_word_under_cursor()
  if not cword or cword == "" then
    return
  end

  -- 1. If keyword is found in Drools Specification DB, render Specification Docs
  if M.show_spec_doc(cword) then
    return
  end

  -- Fallback check using simple cword
  local simple_cword = vim.fn.expand("<cword>")
  if simple_cword ~= cword and M.show_spec_doc(simple_cword) then
    return
  end

  -- 2. Check if active LSP client can handle hover
  local active_clients = vim.lsp.get_active_clients({ bufnr = 0 })
  if #active_clients > 0 then
    vim.lsp.buf.hover()
    return
  end

  -- 3. Fallback to local buffer AST symbol lookup
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Check if word is a bound variable ($var) or type/field
  local clean_word = cword:gsub("^%$", "")
  for i, line in ipairs(lines) do
    if line:match("^%s*declare%s+" .. clean_word) then
      M.show_popup({
        string.format("### Fact Type Declaration: `%s`", clean_word),
        "",
        "Defined at line " .. i .. ":",
        "```drools",
        line,
        "```",
      }, clean_word)
      return
    elseif line:match("%$" .. clean_word .. "%s*:") then
      M.show_popup({
        string.format("### Bound Variable: `$%s`", clean_word),
        "",
        "Binding declared at line " .. i .. ":",
        "```drools",
        line,
        "```",
      }, "$" .. clean_word)
      return
    elseif line:match("^%s*global%s+.-" .. clean_word) then
      M.show_popup({
        string.format("### Global Variable: `%s`", clean_word),
        "",
        "Declared at line " .. i .. ":",
        "```drools",
        line,
        "```",
      }, clean_word)
      return
    end
  end

  vim.notify(string.format("No documentation or definition found for '%s'", cword), vim.log.levels.INFO)
end

--- Handle Ctrl+Click event (move cursor to click position and show definition/hover)
function M.handle_ctrl_click()
  local mouse_pos = vim.fn.getmousepos()
  if mouse_pos and mouse_pos.winid > 0 then
    vim.api.nvim_set_current_win(mouse_pos.winid)
    vim.api.nvim_win_set_cursor(0, { mouse_pos.line, mouse_pos.column - 1 })
  end

  local cword = vim.fn.expand("<cword>")
  local docs = M.get_spec_docs()
  
  -- If it's a spec keyword, show hover docs
  if docs[cword] or docs[cword:lower()] or docs["@" .. cword:lower()] then
    M.show_hover()
  else
    -- Otherwise jump to definition
    require("drools.navigation").goto_definition()
  end
end

return M
