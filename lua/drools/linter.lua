-- lua/drools/linter.lua
-- Grammar-aware DRL tokenizer + recursive descent parser for Drools files
-- Derived from tree-sitter-drools/grammar.js (Apache KIE ANTLR4 DRL specification)

local M = {}

local ns = vim.api.nvim_create_namespace("drools_linter")

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKENIZER
-- ═══════════════════════════════════════════════════════════════════════════

local TOKEN = {
  KEYWORD    = "KEYWORD",
  ATTRIBUTE  = "ATTRIBUTE",
  IDENT      = "IDENT",
  TYPE_IDENT = "TYPE_IDENT",
  BOUND_VAR  = "BOUND_VAR",
  STRING     = "STRING",
  NUMBER     = "NUMBER",
  BOOLEAN    = "BOOLEAN",
  NULL       = "NULL",
  OPERATOR   = "OPERATOR",
  PUNCT      = "PUNCT",
  ANNOTATION = "ANNOTATION",
  NEWLINE    = "NEWLINE",
  EOF        = "EOF",
  ERROR      = "ERROR",
}

local KEYWORDS = {
  ["package"] = true, ["import"] = true, ["global"] = true,
  ["declare"] = true, ["trait"] = true, ["extends"] = true,
  ["rule"] = true, ["query"] = true, ["function"] = true, ["unit"] = true,
  ["when"] = true, ["then"] = true, ["end"] = true,
  ["and"] = true, ["or"] = true, ["not"] = true, ["exists"] = true, ["forall"] = true,
  ["eval"] = true, ["accumulate"] = true, ["collect"] = true,
  ["from"] = true, ["over"] = true,
  ["insert"] = true, ["insertLogical"] = true, ["modify"] = true,
  ["update"] = true, ["retract"] = true, ["delete"] = true,
  ["static"] = true, ["null"] = true, ["true"] = true, ["false"] = true,
  ["in"] = true, ["matches"] = true, ["contains"] = true, ["memberOf"] = true,
  ["soundslike"] = true, ["excludes"] = true,
  ["entry-point"] = true,
}

local ATTRIBUTES = {
  ["salience"] = true, ["agenda-group"] = true, ["ruleflow-group"] = true,
  ["activation-group"] = true, ["lock-on-active"] = true, ["no-loop"] = true,
  ["auto-focus"] = true, ["enabled"] = true, ["dialect"] = true,
  ["duration"] = true, ["timer"] = true, ["calendars"] = true,
  ["date-effective"] = true, ["date-expires"] = true, ["direct"] = true,
}

--- Tokenize a DRL source string into a flat array of tokens
---@param source string Full source text
---@return table[] tokens Array of { type, value, line, col }
---@return table[] errors Array of { message, line, col }
local function tokenize(source)
  local tokens = {}
  local errors = {}
  local pos = 1
  local line = 1
  local col = 1
  local len = #source

  local function peek(offset)
    return source:sub(pos + (offset or 0), pos + (offset or 0))
  end

  local function advance(n)
    n = n or 1
    for i = 1, n do
      if source:sub(pos, pos) == "\n" then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
      pos = pos + 1
    end
  end

  local function emit(ttype, value, start_line, start_col)
    table.insert(tokens, { type = ttype, value = value, line = start_line, col = start_col })
  end

  while pos <= len do
    local ch = source:sub(pos, pos)

    -- Skip whitespace (but track newlines)
    if ch == "\n" then
      advance()
    elseif ch:match("%s") then
      advance()

    -- Line comment
    elseif ch == "/" and peek(1) == "/" then
      while pos <= len and source:sub(pos, pos) ~= "\n" do
        advance()
      end

    -- Block comment
    elseif ch == "/" and peek(1) == "*" then
      local sl, sc = line, col
      advance(2) -- skip /*
      local found_end = false
      while pos <= len - 1 do
        if source:sub(pos, pos) == "*" and source:sub(pos + 1, pos + 1) == "/" then
          advance(2)
          found_end = true
          break
        end
        advance()
      end
      if not found_end then
        if pos <= len then advance() end
        table.insert(errors, { message = "Unterminated block comment '/*' — missing closing '*/'", line = sl, col = sc })
      end

    -- String literal
    elseif ch == '"' or ch == "'" then
      local quote = ch
      local sl, sc = line, col
      advance() -- skip opening quote
      local str_val = quote
      local terminated = false
      while pos <= len do
        local c = source:sub(pos, pos)
        if c == "\\" then
          str_val = str_val .. c
          advance()
          if pos <= len then
            str_val = str_val .. source:sub(pos, pos)
            advance()
          end
        elseif c == quote then
          str_val = str_val .. c
          advance()
          terminated = true
          break
        elseif c == "\n" then
          -- Unterminated string at end of line
          break
        else
          str_val = str_val .. c
          advance()
        end
      end
      if terminated then
        emit(TOKEN.STRING, str_val, sl, sc)
      else
        table.insert(errors, {
          message = string.format("Unterminated string literal — missing closing %s", quote),
          line = sl, col = sc,
        })
        emit(TOKEN.ERROR, str_val, sl, sc)
      end

    -- Annotation (@keyword)
    elseif ch == "@" then
      local sl, sc = line, col
      advance() -- skip @
      local name = ""
      while pos <= len and source:sub(pos, pos):match("[%w_]") do
        name = name .. source:sub(pos, pos)
        advance()
      end
      if name ~= "" then
        emit(TOKEN.ANNOTATION, "@" .. name, sl, sc)
      else
        table.insert(errors, { message = "Invalid annotation — '@' not followed by identifier", line = sl, col = sc })
      end

    -- Bound variable ($identifier)
    elseif ch == "$" then
      local sl, sc = line, col
      advance()
      local name = "$"
      while pos <= len and source:sub(pos, pos):match("[%w_]") do
        name = name .. source:sub(pos, pos)
        advance()
      end
      if #name > 1 then
        emit(TOKEN.BOUND_VAR, name, sl, sc)
      else
        table.insert(errors, { message = "Invalid bound variable — '$' not followed by identifier", line = sl, col = sc })
      end

    -- Number literal
    elseif ch:match("%d") then
      local sl, sc = line, col
      local num = ""
      -- Hex
      if ch == "0" and pos + 1 <= len and source:sub(pos + 1, pos + 1):lower() == "x" then
        num = "0x"
        advance(2)
        while pos <= len and source:sub(pos, pos):match("[%da-fA-F]") do
          num = num .. source:sub(pos, pos)
          advance()
        end
      else
        while pos <= len and source:sub(pos, pos):match("[%d]") do
          num = num .. source:sub(pos, pos)
          advance()
        end
        if pos <= len and source:sub(pos, pos) == "." and pos + 1 <= len and source:sub(pos + 1, pos + 1):match("%d") then
          num = num .. "."
          advance()
          while pos <= len and source:sub(pos, pos):match("%d") do
            num = num .. source:sub(pos, pos)
            advance()
          end
        end
        -- Exponent
        if pos <= len and source:sub(pos, pos):match("[eE]") then
          num = num .. source:sub(pos, pos)
          advance()
          if pos <= len and source:sub(pos, pos):match("[+-]") then
            num = num .. source:sub(pos, pos)
            advance()
          end
          while pos <= len and source:sub(pos, pos):match("%d") do
            num = num .. source:sub(pos, pos)
            advance()
          end
        end
        -- Type suffix
        if pos <= len and source:sub(pos, pos):match("[fFdDlL]") then
          num = num .. source:sub(pos, pos)
          advance()
        end
      end
      emit(TOKEN.NUMBER, num, sl, sc)

    -- Multi-char operators
    elseif ch == "=" and peek(1) == "=" then
      emit(TOKEN.OPERATOR, "==", line, col); advance(2)
    elseif ch == "!" and peek(1) == "=" then
      emit(TOKEN.OPERATOR, "!=", line, col); advance(2)
    elseif ch == ">" and peek(1) == "=" then
      emit(TOKEN.OPERATOR, ">=", line, col); advance(2)
    elseif ch == "<" and peek(1) == "=" then
      emit(TOKEN.OPERATOR, "<=", line, col); advance(2)
    elseif ch == "&" and peek(1) == "&" then
      emit(TOKEN.OPERATOR, "&&", line, col); advance(2)
    elseif ch == "|" and peek(1) == "|" then
      emit(TOKEN.OPERATOR, "||", line, col); advance(2)

    -- Single-char operators
    elseif ch == ">" or ch == "<" then
      emit(TOKEN.OPERATOR, ch, line, col); advance()
    elseif ch == "+" or ch == "-" or ch == "*" or ch == "%" then
      emit(TOKEN.OPERATOR, ch, line, col); advance()
    elseif ch == "=" then
      emit(TOKEN.OPERATOR, "=", line, col); advance()
    elseif ch == "!" then
      emit(TOKEN.OPERATOR, "!", line, col); advance()

    -- Punctuation
    elseif ch == "(" or ch == ")" or ch == "{" or ch == "}" or ch == "[" or ch == "]"
        or ch == ":" or ch == ";" or ch == "," or ch == "." then
      emit(TOKEN.PUNCT, ch, line, col); advance()

    -- Identifiers and keywords
    elseif ch:match("[%a_]") then
      local sl, sc = line, col
      local word = ""
      while pos <= len and source:sub(pos, pos):match("[%w_]") do
        word = word .. source:sub(pos, pos)
        advance()
      end
      -- Check for hyphenated keywords (agenda-group, no-loop, etc.)
      if pos <= len and source:sub(pos, pos) == "-" then
        local save_pos, save_line, save_col = pos, line, col
        local rest = ""
        local temp_pos = pos
        advance() -- skip -
        rest = "-"
        while pos <= len and source:sub(pos, pos):match("[%w_]") do
          rest = rest .. source:sub(pos, pos)
          advance()
        end
        local compound = word .. rest
        if ATTRIBUTES[compound] or compound == "entry-point" then
          word = compound
        else
          -- Backtrack: not a hyphenated keyword
          pos, line, col = save_pos, save_line, save_col
        end
      end

      if word == "true" or word == "false" then
        emit(TOKEN.BOOLEAN, word, sl, sc)
      elseif word == "null" then
        emit(TOKEN.NULL, word, sl, sc)
      elseif ATTRIBUTES[word] then
        emit(TOKEN.ATTRIBUTE, word, sl, sc)
      elseif KEYWORDS[word] then
        emit(TOKEN.KEYWORD, word, sl, sc)
      elseif word:sub(1, 1):match("[A-Z]") then
        emit(TOKEN.TYPE_IDENT, word, sl, sc)
      else
        emit(TOKEN.IDENT, word, sl, sc)
      end

    else
      table.insert(errors, { message = string.format("Unexpected character '%s'", ch), line = line, col = col })
      advance()
    end
  end

  emit(TOKEN.EOF, "", line, col)
  return tokens, errors
end


-- ═══════════════════════════════════════════════════════════════════════════
-- RECURSIVE DESCENT PARSER (follows grammar.js rules)
-- ═══════════════════════════════════════════════════════════════════════════

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens, errors)
  return setmetatable({
    tokens = tokens,
    errors = errors or {},
    pos = 1,
  }, Parser)
end

function Parser:peek(offset)
  local idx = self.pos + (offset or 0)
  return self.tokens[idx] or self.tokens[#self.tokens]
end

function Parser:current()
  return self:peek(0)
end

function Parser:advance()
  local tok = self:current()
  if tok.type ~= TOKEN.EOF then
    self.pos = self.pos + 1
  end
  return tok
end

function Parser:check(ttype, value)
  local tok = self:current()
  if value then
    return tok.type == ttype and tok.value == value
  end
  return tok.type == ttype
end

function Parser:match(ttype, value)
  if self:check(ttype, value) then
    return self:advance()
  end
  return nil
end

function Parser:expect(ttype, value, context)
  local tok = self:match(ttype, value)
  if tok then return tok end

  local cur = self:current()
  local expected = value or ttype
  local msg
  if context then
    msg = string.format("Expected '%s' %s, but found '%s'", expected, context, cur.value ~= "" and cur.value or cur.type)
  else
    msg = string.format("Expected '%s', but found '%s'", expected, cur.value ~= "" and cur.value or cur.type)
  end
  table.insert(self.errors, { message = msg, line = cur.line, col = cur.col })
  return nil
end

function Parser:error(msg, tok)
  tok = tok or self:current()
  table.insert(self.errors, { message = msg, line = tok.line, col = tok.col })
end

--- Skip tokens until we find one of the recovery keywords
function Parser:recover(...)
  local targets = { ... }
  while not self:check(TOKEN.EOF) do
    for _, t in ipairs(targets) do
      if self:current().value == t then return end
    end
    self:advance()
  end
end

--- Parse entire compilation unit
function Parser:parse()
  -- package
  if self:check(TOKEN.KEYWORD, "package") then
    self:parse_package()
  end

  -- top-level declarations in any order
  while not self:check(TOKEN.EOF) do
    local tok = self:current()

    if tok.type == TOKEN.KEYWORD and tok.value == "import" then
      self:parse_import()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "global" then
      self:parse_global()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "declare" then
      self:parse_declare()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "rule" then
      self:parse_rule()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "query" then
      self:parse_query()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "function" then
      self:parse_function()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "unit" then
      self:advance() -- unit
      self:parse_scoped_ident()
      self:match(TOKEN.PUNCT, ";")
    elseif tok.type == TOKEN.ANNOTATION then
      self:advance() -- skip standalone annotations
      if self:check(TOKEN.PUNCT, "(") then
        self:skip_balanced("(", ")")
      end
    else
      self:error(string.format("Unexpected top-level token '%s' — expected rule, declare, import, global, query, or function", tok.value), tok)
      self:advance()
    end
  end
end

-- package com.example.rules;
function Parser:parse_package()
  self:expect(TOKEN.KEYWORD, "package")
  if not self:parse_scoped_ident() then
    self:error("Expected package name after 'package'")
    self:recover("import", "global", "declare", "rule", "query", "function")
    return
  end
  self:match(TOKEN.PUNCT, ";")
end

-- import [static|function] com.example.Model;
function Parser:parse_import()
  self:expect(TOKEN.KEYWORD, "import")
  self:match(TOKEN.KEYWORD, "static")
  self:match(TOKEN.KEYWORD, "function")
  if not self:parse_scoped_ident() then
    self:error("Expected class or package name after 'import'")
    self:recover(";", "import", "global", "declare", "rule")
    return
  end
  -- optional .*
  if self:match(TOKEN.PUNCT, ".") then
    self:expect(TOKEN.OPERATOR, "*", "in wildcard import")
  end
  self:match(TOKEN.PUNCT, ";")
end

-- global java.util.List myList;
function Parser:parse_global()
  self:expect(TOKEN.KEYWORD, "global")
  if not self:parse_scoped_ident() then
    self:error("Expected type name after 'global'")
    self:recover(";", "global", "declare", "rule")
    return
  end
  if not self:match(TOKEN.IDENT) then
    self:error("Expected variable name after global type declaration")
  end
  self:match(TOKEN.PUNCT, ";")
end

-- declare [trait] TypeName [extends Parent] ... fields ... end
function Parser:parse_declare()
  local decl_tok = self:advance() -- 'declare'
  self:match(TOKEN.KEYWORD, "trait")

  local name_tok = self:match(TOKEN.TYPE_IDENT) or self:match(TOKEN.IDENT)
  if not name_tok then
    self:error("Expected type name after 'declare'", decl_tok)
    self:recover("end", "rule", "declare")
    return
  end

  if self:match(TOKEN.KEYWORD, "extends") then
    if not self:parse_scoped_ident() then
      self:error("Expected parent type name after 'extends'")
    end
  end

  -- Parse field declarations and annotations until 'end'
  while not self:check(TOKEN.EOF) and not self:check(TOKEN.KEYWORD, "end") do
    local cur = self:current()

    if cur.type == TOKEN.ANNOTATION then
      self:advance()
      if self:check(TOKEN.PUNCT, "(") then
        self:skip_balanced("(", ")")
      end
    elseif cur.type == TOKEN.IDENT or cur.type == TOKEN.TYPE_IDENT then
      self:parse_field_declaration(name_tok.value)
    elseif cur.type == TOKEN.KEYWORD and (cur.value == "rule" or cur.value == "declare" or cur.value == "query") then
      self:error(string.format("Unclosed 'declare %s' block — missing 'end' before '%s'", name_tok.value, cur.value), decl_tok)
      return
    else
      self:error(string.format("Unexpected token '%s' inside 'declare %s' — expected field declaration (name : Type)", cur.value, name_tok.value), cur)
      self:advance()
    end
  end

  if not self:match(TOKEN.KEYWORD, "end") then
    self:error(string.format("Unclosed 'declare %s' block — missing 'end'", name_tok.value), decl_tok)
  end
end

-- fieldName : TypeName [= defaultValue] [;]
function Parser:parse_field_declaration(declare_name)
  local field_tok = self:advance() -- field name

  if not self:match(TOKEN.PUNCT, ":") then
    local next_tok = self:current()
    if next_tok.type == TOKEN.TYPE_IDENT or next_tok.type == TOKEN.IDENT then
      self:error(
        string.format("Missing ':' separator in field declaration — expected '%s : %s' (colon required between field name and type)", field_tok.value, next_tok.value),
        field_tok
      )
    else
      self:error(
        string.format("Expected ':' after field name '%s' in declare '%s'", field_tok.value, declare_name),
        field_tok
      )
    end
  end

  local type_tok = self:match(TOKEN.TYPE_IDENT) or self:match(TOKEN.IDENT)
  if not type_tok then
    self:error(string.format("Expected type after ':' for field '%s' in declare '%s'", field_tok.value, declare_name))
    self:recover("end", ";")
    return
  end

  -- Optional default value
  if self:match(TOKEN.OPERATOR, "=") then
    -- Skip expression until ; or newline or next field
    while not self:check(TOKEN.EOF)
      and not self:check(TOKEN.PUNCT, ";")
      and not self:check(TOKEN.KEYWORD, "end")
      and not (self:current().type == TOKEN.IDENT and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == ":") do
      self:advance()
    end
  end

  self:match(TOKEN.PUNCT, ";")
end

-- rule "Name" [extends "Parent"] [attributes] when [LHS] then [RHS] end
function Parser:parse_rule()
  local rule_tok = self:advance() -- 'rule'

  local name_tok = self:match(TOKEN.STRING)
  if not name_tok then
    local cur = self:current()
    if cur.type == TOKEN.IDENT or cur.type == TOKEN.TYPE_IDENT then
      self:error(string.format("Rule name must be a quoted string — found '%s' (wrap it in double quotes: \"%s\")", cur.value, cur.value), cur)
      self:advance()
    elseif cur.type == TOKEN.ERROR then
      -- tokenizer already reported unterminated string
      self:advance()
    else
      self:error("Expected quoted rule name after 'rule'", rule_tok)
      self:recover("when", "end", "rule", "declare")
      return
    end
  end

  local rule_name = name_tok and name_tok.value or "<unnamed>"

  -- Optional extends
  if self:match(TOKEN.KEYWORD, "extends") then
    if not self:match(TOKEN.STRING) then
      self:error("Expected quoted rule name after 'extends'")
    end
  end

  -- Rule attributes
  while self:check(TOKEN.ATTRIBUTE) do
    self:parse_rule_attribute(rule_name)
  end

  -- Handle annotations before when
  while self:check(TOKEN.ANNOTATION) do
    self:advance()
    if self:check(TOKEN.PUNCT, "(") then
      self:skip_balanced("(", ")")
    end
  end

  -- when
  if not self:check(TOKEN.KEYWORD, "when") then
    local cur = self:current()
    if cur.type == TOKEN.KEYWORD and cur.value == "end" then
      self:error(string.format("Rule '%s' is missing 'when' and 'then' sections", rule_name), rule_tok)
      self:advance() -- consume end
      return
    elseif cur.type ~= TOKEN.KEYWORD or (cur.value ~= "then" and cur.value ~= "end") then
      self:error(string.format("Expected 'when' keyword in rule '%s', but found '%s' — possible invalid or misspelled rule attribute", rule_name, cur.value), cur)
      self:recover("when", "then", "end", "rule", "declare")
    end
  end
  self:match(TOKEN.KEYWORD, "when")

  -- LHS patterns — skip until 'then'
  self:skip_until_keyword("then", rule_name, "when")

  -- then
  if not self:match(TOKEN.KEYWORD, "then") then
    if self:check(TOKEN.KEYWORD, "end") then
      self:error(string.format("Rule '%s' is missing 'then' section", rule_name), rule_tok)
    end
  end

  -- RHS — skip until 'end'
  self:skip_until_keyword("end", rule_name, "then")

  if not self:match(TOKEN.KEYWORD, "end") then
    self:error(string.format("Rule '%s' is missing closing 'end'", rule_name), rule_tok)
  end
end

function Parser:parse_rule_attribute(rule_name)
  local attr = self:advance() -- attribute name

  -- Attribute value: number, string, boolean, or identifier
  if not (self:match(TOKEN.NUMBER) or self:match(TOKEN.STRING) or self:match(TOKEN.BOOLEAN) or self:match(TOKEN.IDENT)) then
    local cur = self:current()
    if cur.type == TOKEN.KEYWORD and (cur.value == "when" or cur.value == "then" or cur.value == "end") then
      self:error(string.format("Rule attribute '%s' in rule '%s' is missing its value", attr.value, rule_name), attr)
    else
      -- Accept expression-like values (parenthesized salience, etc.)
      if self:check(TOKEN.PUNCT, "(") then
        self:skip_balanced("(", ")")
      end
    end
  end
end

-- query "name" [(params)] ... end
function Parser:parse_query()
  local q_tok = self:advance() -- 'query'
  local name_tok = self:match(TOKEN.STRING) or self:match(TOKEN.IDENT)
  if not name_tok then
    self:error("Expected query name after 'query'", q_tok)
  end

  if self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")")
  end

  -- Skip LHS until end
  while not self:check(TOKEN.EOF) and not self:check(TOKEN.KEYWORD, "end") do
    if self:current().type == TOKEN.KEYWORD and (self:current().value == "rule" or self:current().value == "declare") then
      self:error(string.format("Unclosed query block — missing 'end'"), q_tok)
      return
    end
    self:advance()
  end

  if not self:match(TOKEN.KEYWORD, "end") then
    self:error("Query block is missing closing 'end'", q_tok)
  end
end

-- function ReturnType name(params) { body }
function Parser:parse_function()
  self:advance() -- 'function'
  -- optional return type
  self:match(TOKEN.TYPE_IDENT)
  if not self:match(TOKEN.IDENT) then
    self:error("Expected function name")
  end
  if self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")")
  end
  if self:check(TOKEN.PUNCT, "{") then
    self:skip_balanced("{", "}")
  end
end

--- Parse dot-separated identifier: com.example.Model
function Parser:parse_scoped_ident()
  local tok = self:match(TOKEN.IDENT) or self:match(TOKEN.TYPE_IDENT)
  if not tok then return false end
  while self:match(TOKEN.PUNCT, ".") do
    if not (self:match(TOKEN.IDENT) or self:match(TOKEN.TYPE_IDENT) or self:match(TOKEN.OPERATOR, "*")) then
      self:error("Expected identifier after '.'")
      break
    end
  end
  return true
end

--- Skip balanced delimiters (parens, braces)
function Parser:skip_balanced(open, close)
  if not self:match(TOKEN.PUNCT, open) then return end
  local depth = 1
  while not self:check(TOKEN.EOF) and depth > 0 do
    if self:check(TOKEN.PUNCT, open) then
      depth = depth + 1
    elseif self:check(TOKEN.PUNCT, close) then
      depth = depth - 1
      if depth == 0 then
        self:advance()
        return
      end
    end
    self:advance()
  end
  self:error(string.format("Unmatched '%s' — missing closing '%s'", open, close))
end

--- Skip tokens until a keyword boundary, tracking balanced delimiters
function Parser:skip_until_keyword(keyword, rule_name, section)
  local paren_depth = 0
  local brace_depth = 0
  while not self:check(TOKEN.EOF) do
    local cur = self:current()
    if cur.type == TOKEN.PUNCT and cur.value == "(" then
      paren_depth = paren_depth + 1
    elseif cur.type == TOKEN.PUNCT and cur.value == ")" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        self:error("Unmatched closing parenthesis ')'", cur)
        paren_depth = 0
      end
    elseif cur.type == TOKEN.PUNCT and cur.value == "{" then
      brace_depth = brace_depth + 1
    elseif cur.type == TOKEN.PUNCT and cur.value == "}" then
      brace_depth = brace_depth - 1
      if brace_depth < 0 then
        self:error("Unmatched closing brace '}'", cur)
        brace_depth = 0
      end
    end

    -- Only match keyword at nesting depth 0
    if paren_depth == 0 and brace_depth == 0 and cur.type == TOKEN.KEYWORD and cur.value == keyword then
      break
    end
    -- Recovery: if we hit a new rule/declare/query at depth 0, bail out
    if paren_depth == 0 and brace_depth == 0 and cur.type == TOKEN.KEYWORD
       and (cur.value == "rule" or cur.value == "declare" or cur.value == "query" or cur.value == "import" or cur.value == "global") then
      break
    end
    self:advance()
  end

  if paren_depth > 0 then
    self:error(string.format("Unmatched opening parenthesis '(' in '%s' section of rule '%s'", section, rule_name))
  end
  if brace_depth > 0 then
    self:error(string.format("Unmatched opening brace '{' in '%s' section of rule '%s'", section, rule_name))
  end
end


-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════

--- Perform grammar-aware linting on a specific buffer
---@param bufnr number Buffer number
function M.lint(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "drools" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local source = table.concat(lines, "\n")

  -- Phase 1: Tokenize
  local tokens, tokenizer_errors = tokenize(source)

  -- Phase 2: Parse
  local parser = Parser.new(tokens, tokenizer_errors)
  parser:parse()

  -- Convert errors to Neovim diagnostics
  local diagnostics = {}
  for _, err in ipairs(parser.errors) do
    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = (err.line or 1) - 1, -- 0-indexed
      col = (err.col or 1) - 1,   -- 0-indexed
      severity = vim.diagnostic.severity.ERROR,
      message = err.message,
      source = "drools-parser",
    })
  end

  -- Phase 3: Tree-sitter AST errors (if parser is compiled and available)
  local ts_ok, ts_parser = pcall(vim.treesitter.get_parser, bufnr, "drools")
  if ts_ok and ts_parser then
    local tree = ts_parser:parse()[1]
    if tree then
      local root = tree:root()
      local query_str = "(ERROR) @error"
      local q_ok, query = pcall(vim.treesitter.query.parse, "drools", query_str)
      if q_ok and query then
        for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
          local start_row, start_col, end_row, end_col = node:range()
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = start_row,
            col = start_col,
            end_lnum = end_row,
            end_col = end_col,
            severity = vim.diagnostic.severity.ERROR,
            message = "Syntax error (Tree-sitter parse failure)",
            source = "drools-treesitter",
          })
        end
      end
    end
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

local attached_buffers = {}

--- Attach real-time live linter to a buffer using nvim_buf_attach
---@param bufnr number Buffer handle
---@param opts table Linter options
local function attach_linter(bufnr, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  if vim.bo[bufnr].filetype ~= "drools" then return end
  if attached_buffers[bufnr] then return end

  attached_buffers[bufnr] = true
  local debounce_ms = (opts and opts.debounce_ms) or 100
  local timer = nil

  local function trigger_lint()
    if timer then
      pcall(vim.fn.timer_stop, timer)
      timer = nil
    end
    timer = vim.fn.timer_start(debounce_ms, function()
      timer = nil
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "drools" then
          M.lint(bufnr)
        end
      end)
    end)
  end

  -- Initial lint when buffer attached
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.lint(bufnr)
    end
  end)

  -- Attach native buffer line listener (triggers instantly on every character typed)
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "drools" then
        return true -- detach
      end
      trigger_lint()
    end,
    on_detach = function(_, buf)
      attached_buffers[buf] = nil
    end,
  })
end

local current_mode = "insert_leave"

function M.set_mode(mode)
  mode = (mode or "insert_leave"):lower()
  if mode == "insert_leave" then
    current_mode = "insert_leave"
    vim.diagnostic.config({ update_in_insert = false })
    vim.notify("Drools Linter Mode set to 'insert_leave' (diagnostics update when exiting Insert mode)", vim.log.levels.INFO)
  elseif mode == "live" then
    current_mode = "live"
    vim.diagnostic.config({ update_in_insert = true })
    vim.notify("Drools Linter Mode set to 'live' (diagnostics update DURING Insert mode as you type)", vim.log.levels.INFO)
  elseif mode == "on_save" then
    current_mode = "on_save"
    vim.diagnostic.config({ update_in_insert = false })
    vim.notify("Drools Linter Mode set to 'on_save' (diagnostics update ONLY on file save)", vim.log.levels.INFO)
  else
    vim.notify("Invalid linter mode: " .. tostring(mode) .. ". Valid options: 'insert_leave', 'live', 'on_save'", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}
  local mode = opts.mode or "insert_leave"
  M.set_mode(mode)

  local group = vim.api.nvim_create_augroup("DroolsLinter", { clear = true })

  -- Attach to all currently open Drools buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "drools" then
      attach_linter(buf, opts)
    end
  end

  -- Auto-attach on FileType, BufEnter, BufReadPost, BufWinEnter
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufReadPost", "BufWinEnter" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.bo[args.buf].filetype == "drools" then
        attach_linter(args.buf, opts)
      end
    end,
  })

  -- Lint on save
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.bo[args.buf].filetype == "drools" then
        M.lint(args.buf)
      end
    end,
  })
end

return M
