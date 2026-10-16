-- lua/drools/hover.lua
-- Documentation hover and mouse interaction engine for Drools Rule Language

local M = {}

local docs_cache = nil
M.current_hover_win = nil
M.current_hover_buf = nil
local mouse_timer = nil
local last_mouse_word = nil
local last_mouse_pos = { line = -1, col = -1 }

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

  if relative_to ~= "mouse" then
    vim.notify(string.format("No documentation or definition found for '%s'", cword), vim.log.levels.INFO)
  end
end

--- Handle Ctrl+Click event (move cursor to clicked position and show definition or specification hover)
function M.handle_ctrl_click()
  local mouse_pos = vim.fn.getmousepos()
  if mouse_pos and mouse_pos.winid > 0 and mouse_pos.line > 0 then
    local cur_win = vim.api.nvim_get_current_win()
    if mouse_pos.winid ~= cur_win then
      pcall(vim.api.nvim_set_current_win, mouse_pos.winid)
    end
    local line_count = vim.api.nvim_buf_line_count(0)
    local target_line = math.min(mouse_pos.line, line_count)
    local line_str = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1] or ""
    local target_col = math.min(math.max(0, mouse_pos.column - 1), math.max(0, #line_str - 1))
    pcall(vim.api.nvim_win_set_cursor, 0, { target_line, target_col })
  end

  local cword = M.get_word_under_cursor()
  local docs = M.get_spec_docs()

  -- If it's an official spec keyword or annotation, render specification docs
  if docs[cword] or docs[cword:lower()] or docs["@" .. cword:lower()] then
    M.show_hover()
  else
    -- Otherwise jump to definition (or show symbol popup if already at definition)
    local jumped = require("drools.navigation").goto_definition()
    if not jumped then
      M.show_hover()
    end
  end
end

--- Handle Double-Click event
function M.handle_double_click()
  M.handle_ctrl_click()
end

--- Handle Mouse Movement hover with debounce
function M.handle_mouse_move()
  if vim.bo.filetype ~= "drools" and vim.bo.filetype ~= "dsl" then
    return
  end

  local m = vim.fn.getmousepos()
  if not m or m.winid == 0 or m.line <= 0 or m.column <= 0 then
    if M.current_hover_win then
      M.close_hover()
    end
    return
  end

  -- Don't trigger if mouse is inside the floating hover window itself
  if M.current_hover_win and m.winid == M.current_hover_win then
    return
  end

  -- Check if mouse is on a valid line in the window
  local bufnr = vim.api.nvim_win_get_buf(m.winid)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if m.line > line_count then
    return
  end

  local line_str = vim.api.nvim_buf_get_lines(bufnr, m.line - 1, m.line, false)[1] or ""
  local word = M.get_word_under_cursor(line_str, m.column)

  if not word or word == "" or #word <= 1 or word:match("^%d+$") then
    if last_mouse_word and M.current_hover_win then
      M.close_hover()
      last_mouse_word = nil
    end
    return
  end

  if word == last_mouse_word and m.line == last_mouse_pos.line then
    return
  end

  last_mouse_word = word
  last_mouse_pos = { line = m.line, col = m.column }

  -- Cancel existing timer
  if mouse_timer then
    mouse_timer:stop()
    mouse_timer:close()
    mouse_timer = nil
  end

  local uv = vim.uv or vim.loop
  mouse_timer = uv.new_timer()
  mouse_timer:start(500, 0, vim.schedule_wrap(function()
    if mouse_timer then
      mouse_timer:close()
      mouse_timer = nil
    end

    local current_m = vim.fn.getmousepos()
    if current_m and current_m.line == last_mouse_pos.line then
      -- Verify cursor / buffer is still drools
      if vim.bo.filetype == "drools" or vim.bo.filetype == "dsl" then
        local docs = M.get_spec_docs()
        if docs[word] or docs[word:lower()] or docs["@" .. word:lower()] then
          M.show_spec_doc(word, "mouse")
        end
      end
    end
  end))
end

--- Setup mouse interaction and optional mousemoveevent listener
---@param opts table|nil
function M.setup_mouse(opts)
  opts = opts or {}
  if opts.enable == false then
    return
  end

  -- Enable mouse in Neovim if not already enabled
  if not vim.o.mouse or vim.o.mouse == "" then
    vim.o.mouse = "a"
  end

  -- Enable mousemoveevent if hover tooltips are enabled
  if opts.hover ~= false and vim.o.mousemoveevent ~= nil then
    pcall(function() vim.o.mousemoveevent = true end)

    local group = vim.api.nvim_create_augroup("DroolsMouseHover", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = { "drools", "dsl" },
      callback = function(args)
        vim.keymap.set({ "n", "v" }, "<MouseMove>", function()
          M.handle_mouse_move()
        end, { buffer = args.buf, silent = true, desc = "Drools: Mouse Hover Tooltip" })
      end,
    })
  end
end

return M
