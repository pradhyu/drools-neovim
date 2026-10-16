-- lua/drools/linter.lua
-- Comprehensive Grammar-Aware DRL Tokenizer & Recursive Descent Parser for Drools (.drl)
-- Supports full Apache KIE Drools DRL specification (6/7/8), multiline constructs,
-- Java/MVEL consequence blocks (then), function declarations, declare blocks
-- (types, traits, enums, windows, entry-points), queries, units, CEP temporal operators,
-- OOPath expressions, accumulate/collect clauses, and contextual soft keywords.

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
  EOF        = "EOF",
  ERROR      = "ERROR",
}

local KEYWORDS = {
  ["package"] = true, ["import"] = true, ["global"] = true,
  ["declare"] = true, ["trait"] = true, ["extends"] = true,
  ["rule"] = true, ["query"] = true, ["function"] = true, ["unit"] = true,
  ["when"] = true, ["then"] = true, ["end"] = true,
  ["and"] = true, ["or"] = true, ["not"] = true, ["exists"] = true, ["forall"] = true,
  ["eval"] = true, ["accumulate"] = true, ["acc"] = true, ["collect"] = true, ["groupby"] = true,
  ["from"] = true, ["over"] = true, ["window"] = true, ["enum"] = true,
  ["insert"] = true, ["insertLogical"] = true, ["modify"] = true,
  ["update"] = true, ["retract"] = true, ["delete"] = true,
  ["static"] = true, ["null"] = true, ["true"] = true, ["false"] = true,
  ["in"] = true, ["notin"] = true, ["matches"] = true, ["contains"] = true, ["memberOf"] = true,
  ["soundslike"] = true, ["excludes"] = true, ["str"] = true,
  ["after"] = true, ["before"] = true, ["coincides"] = true, ["during"] = true,
  ["finishes"] = true, ["finishedby"] = true, ["meets"] = true, ["metby"] = true,
  ["overlaps"] = true, ["overlappedby"] = true, ["starts"] = true, ["startedby"] = true,
  ["entry-point"] = true,
}

local ATTRIBUTES = {
  ["salience"] = true, ["agenda-group"] = true, ["ruleflow-group"] = true,
  ["activation-group"] = true, ["lock-on-active"] = true, ["no-loop"] = true,
  ["auto-focus"] = true, ["enabled"] = true, ["dialect"] = true,
  ["duration"] = true, ["timer"] = true, ["calendars"] = true,
  ["date-effective"] = true, ["date-expires"] = true, ["refract"] = true,
  ["direct"] = true,
}

-- Rule attributes where the boolean value ('true') is optional when omitted
local OPTIONAL_BOOL_ATTRIBUTES = {
  ["no-loop"] = true,
  ["lock-on-active"] = true,
  ["auto-focus"] = true,
  ["refract"] = true,
  ["direct"] = true,
}

-- Rule attributes that require a string value
local STRING_ATTRIBUTES = {
  ["agenda-group"] = true,
  ["ruleflow-group"] = true,
  ["activation-group"] = true,
  ["dialect"] = true,
  ["date-effective"] = true,
  ["date-expires"] = true,
}

-- Operators that are binary/prefix and cannot legally be the final token before ')', ';', ',', '}'
local DANGLING_OPERATORS = {
  ["="] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true,
  ["=="] = true, ["!="] = true, ["<="] = true, [">="] = true, ["~="] = true,
  ["&&"] = true, ["||"] = true,
  ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true,
  ["<"] = true, ["!"] = true,
}

-- Relational operators allowed in Drools abbreviated combined relation conditions (e.g. `age > 30 && < 40`, `age ((> 30 && < 40) || (> 20 && < 25))`)
local RELATIONAL_OPERATORS = {
  ["=="] = true, ["!="] = true, ["<="] = true, [">="] = true, ["<"] = true, [">"] = true, ["~="] = true,
}

-- Operators that are pure binary comparison/logical/assignment and cannot immediately follow ','
local LEADING_BINARY_OPERATORS = {
  ["="] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true,
  ["=="] = true, ["!="] = true, ["<="] = true, [">="] = true, ["<"] = true, [">"] = true,
  ["&&"] = true, ["||"] = true, ["*"] = true, ["/"] = true, ["%"] = true,
}

-- Operators that can NEVER immediately follow '(' (excludes relational operators which are valid in `age ((> 30 && < 40))`)
local INVALID_AFTER_OPEN_PAREN = {
  ["="] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true,
  ["&&"] = true, ["||"] = true, ["*"] = true, ["/"] = true, ["%"] = true,
}

--- Check whether a multiline string starting at `start_pos` with `quote` has a valid closing quote
--- before hitting a top-level structural boundary on a subsequent line.
local function has_multiline_string_close(source, cur_pos, quote, prev_tok)
  -- Header strings (after rule, extends, query, package/attribute names) must be single-line
  if prev_tok then
    local pv = prev_tok.value
    if pv == "rule" or pv == "extends" or pv == "query" or pv == "entry-point"
       or STRING_ATTRIBUTES[pv] or pv == "calendars" then
      return false
    end
  end

  local len = #source
  local p = cur_pos
  while p <= len do
    local c = source:sub(p, p)
    if c == "\\" then
      p = p + 2
    elseif c == quote then
      return true
    elseif c == "\n" then
      -- Check if the next line starts with a structural DRL keyword at indentation level
      local line_end = source:find("\n", p + 1) or (len + 1)
      local next_line = source:sub(p + 1, line_end - 1)
      local first_word = next_line:match("^%s*([%a_][%w_%-]*)")
      if first_word == "when" or first_word == "then" or first_word == "end"
         or first_word == "rule" or first_word == "declare" or first_word == "query"
         or first_word == "function" then
        return false
      end
      p = p + 1
    else
      p = p + 1
    end
  end
  return false
end

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
    local idx = pos + (offset or 0)
    if idx > len then return "" end
    return source:sub(idx, idx)
  end

  local function peek_str(n)
    return source:sub(pos, math.min(len, pos + n - 1))
  end

  local function advance(n)
    n = n or 1
    for _ = 1, n do
      if pos <= len then
        if source:sub(pos, pos) == "\n" then
          line = line + 1
          col = 1
        else
          col = col + 1
        end
        pos = pos + 1
      end
    end
  end

  local function emit(ttype, value, start_line, start_col)
    table.insert(tokens, { type = ttype, value = value, line = start_line, col = start_col })
  end

  while pos <= len do
    local ch = source:sub(pos, pos)

    -- 1. Whitespace
    if ch:match("%s") then
      advance()

    -- 2. Line comment //
    elseif ch == "/" and peek(1) == "/" then
      while pos <= len and source:sub(pos, pos) ~= "\n" do
        advance()
      end

    -- 3. Line comment # (when at start of file, start of line, or preceded by whitespace)
    elseif ch == "#" and (pos == 1 or source:sub(pos - 1, pos - 1):match("%s")) then
      while pos <= len and source:sub(pos, pos) ~= "\n" do
        advance()
      end

    -- 4. Block comment /* ... */
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
        while pos <= len do advance() end
        table.insert(errors, { message = "Unterminated block comment '/*' — missing closing '*/'", line = sl, col = sc })
      end

    -- 5. Triple-quoted multiline text block """ ... """
    elseif peek_str(3) == '"""' then
      local sl, sc = line, col
      advance(3)
      local str_val = '"""'
      local terminated = false
      while pos <= len do
        if peek_str(3) == '"""' then
          str_val = str_val .. '"""'
          advance(3)
          terminated = true
          break
        elseif source:sub(pos, pos) == "\\" then
          str_val = str_val .. source:sub(pos, pos)
          advance()
          if pos <= len then
            str_val = str_val .. source:sub(pos, pos)
            advance()
          end
        else
          str_val = str_val .. source:sub(pos, pos)
          advance()
        end
      end
      if terminated then
        emit(TOKEN.STRING, str_val, sl, sc)
      else
        table.insert(errors, {
          message = 'Unterminated multiline text block — missing closing """',
          line = sl, col = sc,
        })
        emit(TOKEN.ERROR, str_val, sl, sc)
      end

    -- 6. String or char literal ("..." or '...')
    elseif ch == '"' or ch == "'" then
      local quote = ch
      local sl, sc = line, col
      local prev_tok = tokens[#tokens]
      advance() -- skip opening quote
      local str_val = quote
      local terminated = false
      local allow_multiline = nil

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
          if allow_multiline == nil then
            allow_multiline = has_multiline_string_close(source, pos, quote, prev_tok)
          end
          if allow_multiline then
            str_val = str_val .. c
            advance()
          else
            break
          end
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

    -- 7. Annotation (@keyword or @pkg.AnnotationName)
    elseif ch == "@" then
      local sl, sc = line, col
      advance() -- skip @
      local name = ""
      while pos <= len and source:sub(pos, pos):match("[%w_]") do
        name = name .. source:sub(pos, pos)
        advance()
        if pos < len and source:sub(pos, pos) == "." and source:sub(pos + 1, pos + 1):match("[%a_]") then
          name = name .. "."
          advance()
        end
      end
      if name ~= "" then
        emit(TOKEN.ANNOTATION, "@" .. name, sl, sc)
      else
        table.insert(errors, { message = "Invalid annotation — '@' not followed by identifier", line = sl, col = sc })
      end

    -- 8. Bound variable ($identifier)
    elseif ch == "$" then
      local sl, sc = line, col
      advance()
      local name = "$"
      while pos <= len and source:sub(pos, pos):match("[%w_%$]") do
        name = name .. source:sub(pos, pos)
        advance()
      end
      if #name > 1 then
        emit(TOKEN.BOUND_VAR, name, sl, sc)
      else
        table.insert(errors, { message = "Invalid bound variable — '$' not followed by identifier", line = sl, col = sc })
      end

    -- 9. Number literal (including hex, binary, scientific, BigDecimal B/I, and temporal 5m/30s/1h30m)
    elseif ch:match("%d") or (ch == "." and peek(1):match("%d")) then
      local sl, sc = line, col
      local num = ""
      if ch == "0" and (peek(1) == "x" or peek(1) == "X") then
        num = source:sub(pos, pos + 1)
        advance(2)
        while pos <= len and source:sub(pos, pos):match("[%da-fA-F_]") do
          num = num .. source:sub(pos, pos)
          advance()
        end
        if pos <= len and source:sub(pos, pos):match("[lL]") then
          num = num .. source:sub(pos, pos)
          advance()
        end
      elseif ch == "0" and (peek(1) == "b" or peek(1) == "B") and peek(2):match("[01]") then
        num = source:sub(pos, pos + 1)
        advance(2)
        while pos <= len and source:sub(pos, pos):match("[01_]") do
          num = num .. source:sub(pos, pos)
          advance()
        end
        if pos <= len and source:sub(pos, pos):match("[lL]") then
          num = num .. source:sub(pos, pos)
          advance()
        end
      else
        while pos <= len and source:sub(pos, pos):match("[%d_]") do
          num = num .. source:sub(pos, pos)
          advance()
        end
        if pos <= len and source:sub(pos, pos) == "." and peek(1):match("%d") then
          num = num .. "."
          advance()
          while pos <= len and source:sub(pos, pos):match("[%d_]") do
            num = num .. source:sub(pos, pos)
            advance()
          end
        end
        -- Exponent
        if pos <= len and source:sub(pos, pos):match("[eE]") and (peek(1):match("%d") or (peek(1):match("[+-]") and peek(2):match("%d"))) then
          num = num .. source:sub(pos, pos)
          advance()
          if pos <= len and source:sub(pos, pos):match("[+-]") then
            num = num .. source:sub(pos, pos)
            advance()
          end
          while pos <= len and source:sub(pos, pos):match("[%d_]") do
            num = num .. source:sub(pos, pos)
            advance()
          end
        end
        -- Temporal / duration units (e.g., 100ms, 30s, 5m, 1h30m, 2d12h) or numeric type suffix (f, d, l, B, I)
        if pos <= len then
          local rem = source:sub(pos)
          local temporal = rem:match("^([dhms]+[%d]*[dhms]*[%d]*[dhms]*)")
          if temporal and not rem:match("^[%a_][%w_]*") or (temporal and temporal:match("^ms$") or temporal and temporal:match("^[dhms]$")) then
            -- Consume compound duration literals like 1h30m10s, 5m, 30s, 100ms
            while pos <= len do
              local sub_rem = source:sub(pos)
              local unit = sub_rem:match("^(ms)") or sub_rem:match("^([dhms])")
              if unit then
                local after_unit = source:sub(pos + #unit, pos + #unit)
                if after_unit:match("[%a_]") then
                  break
                end
                num = num .. unit
                advance(#unit)
                -- Check if another <digits><unit> immediately follows (e.g. 1h30m)
                local next_digits, next_u = source:sub(pos):match("^(%d+)(ms|[dhms])")
                if next_digits and next_u then
                  num = num .. next_digits
                  advance(#next_digits)
                else
                  break
                end
              else
                break
              end
            end
          elseif source:sub(pos, pos):match("[fFdDlLbBiI]") and not peek(1):match("[%w_]") then
            num = num .. source:sub(pos, pos)
            advance()
          end
        end
      end
      emit(TOKEN.NUMBER, num, sl, sc)

    -- 10. Multi-character operators & punctuation
    elseif peek_str(4) == ">>>=" then
      emit(TOKEN.OPERATOR, ">>>=", line, col); advance(4)
    elseif peek_str(3) == ">>>" or peek_str(3) == "<<=" or peek_str(3) == ">>=" or peek_str(3) == "<=>" then
      emit(TOKEN.OPERATOR, peek_str(3), line, col); advance(3)
    elseif peek_str(3) == "..." then
      emit(TOKEN.PUNCT, "...", line, col); advance(3)
    elseif peek_str(2) == "==" or peek_str(2) == "!=" or peek_str(2) == ">=" or peek_str(2) == "<="
        or peek_str(2) == "&&" or peek_str(2) == "||" or peek_str(2) == "++" or peek_str(2) == "--"
        or peek_str(2) == "+=" or peek_str(2) == "-=" or peek_str(2) == "*=" or peek_str(2) == "/="
        or peek_str(2) == "%=" or peek_str(2) == "&=" or peek_str(2) == "|=" or peek_str(2) == "^="
        or peek_str(2) == "<<" or peek_str(2) == ">>" or peek_str(2) == "->" or peek_str(2) == "~="
        or peek_str(2) == ":=" then
      emit(TOKEN.OPERATOR, peek_str(2), line, col); advance(2)
    elseif peek_str(2) == "::" or peek_str(2) == "?." or peek_str(2) == "!." or peek_str(2) == ".." then
      emit(TOKEN.PUNCT, peek_str(2), line, col); advance(2)

    -- 11. Single-character operators
    elseif ch == ">" or ch == "<" or ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%"
        or ch == "=" or ch == "!" or ch == "&" or ch == "|" or ch == "^" or ch == "~" or ch == "?" then
      emit(TOKEN.OPERATOR, ch, line, col); advance()

    -- 12. Punctuation
    elseif ch == "(" or ch == ")" or ch == "{" or ch == "}" or ch == "[" or ch == "]"
        or ch == ":" or ch == ";" or ch == "," or ch == "." or ch == "#" then
      emit(TOKEN.PUNCT, ch, line, col); advance()

    -- 13. Identifiers, Type Identifiers, Attributes, and Keywords
    elseif ch:match("[%a_]") then
      local sl, sc = line, col
      local prev_tok = tokens[#tokens]
      local after_dot = prev_tok and prev_tok.type == TOKEN.PUNCT
        and (prev_tok.value == "." or prev_tok.value == "?." or prev_tok.value == "!." or prev_tok.value == "::")

      local word = ""
      while pos <= len and source:sub(pos, pos):match("[%w_%$]") do
        word = word .. source:sub(pos, pos)
        advance()
      end

      -- Check for multi-segment hyphenated keywords/attributes (e.g. agenda-group, lock-on-active, entry-point)
      if not after_dot and pos <= len and source:sub(pos, pos) == "-" then
        local save_pos, save_line, save_col = pos, line, col
        local compound = word
        while pos <= len and source:sub(pos, pos) == "-" and peek(1):match("[%a_]") do
          compound = compound .. "-"
          advance() -- skip '-'
          while pos <= len and source:sub(pos, pos):match("[%w_]") do
            compound = compound .. source:sub(pos, pos)
            advance()
          end
        end
        if ATTRIBUTES[compound] or KEYWORDS[compound] then
          word = compound
        else
          pos, line, col = save_pos, save_line, save_col
        end
      end

      if word == "true" or word == "false" then
        emit(TOKEN.BOOLEAN, word, sl, sc)
      elseif word == "null" then
        emit(TOKEN.NULL, word, sl, sc)
      elseif not after_dot and ATTRIBUTES[word] then
        emit(TOKEN.ATTRIBUTE, word, sl, sc)
      elseif not after_dot and KEYWORDS[word] then
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
-- RECURSIVE DESCENT PARSER
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
  if idx < 1 then return self.tokens[1] end
  return self.tokens[idx] or self.tokens[#self.tokens]
end

function Parser:current()
  return self:peek(0)
end

function Parser:prev()
  if self.pos > 1 then
    return self.tokens[self.pos - 1]
  end
  return nil
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

--- Check if a token can act as an identifier (including soft keywords and attributes when used as names)
function Parser:is_ident_like(tok)
  tok = tok or self:current()
  if tok.type == TOKEN.IDENT or tok.type == TOKEN.TYPE_IDENT then
    return true
  end
  if (tok.type == TOKEN.KEYWORD or tok.type == TOKEN.ATTRIBUTE) and not tok.value:find("-", 1, true) then
    return true
  end
  return false
end

function Parser:match_ident_like()
  if self:is_ident_like(self:current()) then
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

--- Check if current token is on a new line compared to the previous token
function Parser:is_at_line_start(offset)
  local idx = self.pos + (offset or 0)
  local tok = self.tokens[idx]
  local prev = self.tokens[idx - 1]
  if not tok then return false end
  if not prev then return true end
  return tok.line > prev.line
end

--- Check if current token is a genuine DRL block-closing `end` keyword (and NOT `obj.end()`, `int end = 1;`, etc.)
function Parser:is_standalone_end()
  local cur = self:current()
  if cur.type ~= TOKEN.KEYWORD or cur.value ~= "end" then
    return false
  end

  local prev = self:prev()
  local next_tok = self:peek(1)

  -- Cannot be preceded by '.', '?.', '::', or Java expression/declaration starters on the same statement
  if prev then
    if prev.value == "." or prev.value == "?." or prev.value == "!." or prev.value == "::"
       or prev.value == "return" or prev.value == "throw" or prev.value == "new"
       or prev.value == "," or DANGLING_OPERATORS[prev.value] then
      return false
    end
    -- If preceded by ':', it is only valid if ':' is part of `when:` or `then:`
    if prev.value == ":" then
      local before_colon = self:peek(-2)
      if not before_colon or (before_colon.value ~= "then" and before_colon.value ~= "when") then
        return false
      end
    end
    -- If on the same line as previous token, previous token must be ';', '}', ')', 'then', 'when', or ':'
    if prev.line == cur.line then
      local pv = prev.value
      if pv ~= ";" and pv ~= "}" and pv ~= ")" and pv ~= "then" and pv ~= "when" and pv ~= ":" then
        return false
      end
    end
  end

  -- Cannot be followed by '(', '.', '[', '=', '++', '--', ':', '?' or binary operators
  if next_tok and next_tok.type ~= TOKEN.EOF then
    local nv = next_tok.value
    if nv == "(" or nv == "." or nv == "?." or nv == "!." or nv == "::"
       or nv == "[" or nv == ":" or nv == "?" or nv == ","
       or nv == "++" or nv == "--" or DANGLING_OPERATORS[nv] or nv == ">" then
      return false
    end
  end

  return true
end

--- Check if current token is a standalone `then` section header (and NOT `future.then(...)` or variable `then`)
function Parser:is_standalone_then()
  local cur = self:current()
  if cur.type ~= TOKEN.KEYWORD or cur.value ~= "then" then
    return false
  end
  local prev = self:prev()
  local next_tok = self:peek(1)
  if prev and (prev.value == "." or prev.value == "?." or prev.value == "::") then
    return false
  end
  if next_tok and (next_tok.value == "(" or next_tok.value == "." or next_tok.value == "=") then
    return false
  end
  return true
end

--- Check if current token is a standalone `when` section header
function Parser:is_standalone_when()
  local cur = self:current()
  if cur.type ~= TOKEN.KEYWORD or cur.value ~= "when" then
    return false
  end
  local prev = self:prev()
  local next_tok = self:peek(1)
  if prev and (prev.value == "." or prev.value == "?." or prev.value == "::") then
    return false
  end
  if next_tok and (next_tok.value == "(" or next_tok.value == "." or next_tok.value == "=") then
    return false
  end
  return true
end

--- Check if current token at depth 0 is unmistakably the start of a new top-level DRL block
--- (used for error recovery when a previous rule/declare/query/function forgot its closing 'end' or '}')
function Parser:is_new_top_level_block()
  if not self:is_at_line_start() then
    return false
  end
  local cur = self:current()
  local next_tok = self:peek(1)
  if cur.type ~= TOKEN.KEYWORD then
    return false
  end

  if cur.value == "rule" then
    -- `rule "Name"` or `rule Name` followed by attributes/when/extends (and not `rule = ...` or `rule.foo`)
    if next_tok.type == TOKEN.STRING or next_tok.type == TOKEN.ERROR then
      return true
    end
    local after_next = self:peek(2)
    return self:is_ident_like(next_tok) and next_tok.value ~= "when" and next_tok.value ~= "then" and next_tok.value ~= "end"
      and after_next and (after_next.line > next_tok.line or after_next.value == "extends" or after_next.value == "when" or after_next.type == TOKEN.ATTRIBUTE)
  elseif cur.value == "query" then
    if next_tok.type == TOKEN.STRING or next_tok.type == TOKEN.ERROR then
      return true
    end
    local after_next = self:peek(2)
    return self:is_ident_like(next_tok) and after_next and (after_next.line > next_tok.line or after_next.value == "(")
  elseif cur.value == "declare" then
    return self:is_ident_like(next_tok) or next_tok.value == "entry-point"
  elseif cur.value == "function" then
    -- `function [Type] name(`
    return self:is_ident_like(next_tok) and next_tok.value ~= "=" and next_tok.value ~= "."
  end
  return false
end

--- Skip tokens until we find one of the recovery keywords at line start or ';'/EOF
function Parser:recover(...)
  local targets = {}
  for _, t in ipairs({ ... }) do
    targets[t] = true
  end
  while not self:check(TOKEN.EOF) do
    local cur = self:current()
    if targets[cur.value] then
      return
    end
    if self:is_new_top_level_block() then
      return
    end
    self:advance()
  end
end

--- Parse dot-separated identifier: com.example.Model (allows soft keywords as package/class segments)
function Parser:parse_scoped_ident(allow_wildcard)
  local first = self:match_ident_like()
  if not first then return nil end
  local full = first.value

  while self:match(TOKEN.PUNCT, ".") do
    if allow_wildcard and self:match(TOKEN.OPERATOR, "*") then
      full = full .. ".*"
      break
    end
    local seg = self:match_ident_like()
    if not seg then
      self:error("Expected identifier after '.'")
      break
    end
    full = full .. "." .. seg.value
  end
  return full
end

--- Parse a full Java/Drools type specification:
--- Supports primitives (int, boolean, void), scoped types (java.util.List),
--- nested generics (Map<String, List<? extends Order>>), and arrays (String[][]).
function Parser:parse_type()
  local base = self:parse_scoped_ident(false)
  if not base then return nil end

  -- Optional generic type parameters: < ... >
  if self:check(TOKEN.OPERATOR, "<") then
    local open_tok = self:advance() -- consume '<'
    local depth = 1
    while not self:check(TOKEN.EOF) and depth > 0 do
      local cur = self:current()
      if cur.type == TOKEN.OPERATOR and cur.value == "<" then
        depth = depth + 1
      elseif cur.type == TOKEN.OPERATOR and cur.value == ">" then
        depth = depth - 1
      elseif cur.type == TOKEN.OPERATOR and cur.value == ">>" then
        depth = math.max(0, depth - 2)
      elseif cur.type == TOKEN.OPERATOR and cur.value == ">>>" then
        depth = math.max(0, depth - 3)
      elseif cur.type == TOKEN.PUNCT and (cur.value == ";" or cur.value == "{" or cur.value == "}") then
        self:error("Unclosed generic type '<' — missing closing '>'", open_tok)
        return base
      elseif self:is_new_top_level_block() then
        self:error("Unclosed generic type '<' — missing closing '>'", open_tok)
        return base
      end
      self:advance()
    end
  end

  -- Optional array dimensions: [] [][]
  while self:check(TOKEN.PUNCT, "[") and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "]" do
    self:advance() -- '['
    self:advance() -- ']'
  end

  -- Optional varargs: ...
  self:match(TOKEN.PUNCT, "...")

  return base
end

--- Parse entire compilation unit
function Parser:parse()
  while not self:check(TOKEN.EOF) do
    local tok = self:current()

    if tok.type == TOKEN.KEYWORD and tok.value == "package" then
      self:parse_package()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "unit" then
      self:parse_unit()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "import" then
      self:parse_import()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "global" then
      self:parse_global()
    elseif tok.type == TOKEN.ATTRIBUTE then
      -- Package-level rule attributes (e.g. `dialect "mvel"`, `date-effective "..."`)
      self:parse_rule_attribute("<package>")
      self:match(TOKEN.PUNCT, ";")
    elseif tok.type == TOKEN.KEYWORD and tok.value == "declare" then
      self:parse_declare()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "rule" then
      self:parse_rule()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "query" then
      self:parse_query()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "function" then
      self:parse_function()
    elseif tok.type == TOKEN.ANNOTATION then
      self:parse_annotation()
    elseif tok.type == TOKEN.PUNCT and tok.value == ";" then
      self:advance() -- allow extra semicolons at top-level
    elseif tok.type == TOKEN.KEYWORD and tok.value == "end" then
      self:error("Unmatched 'end' keyword outside of any rule, declare, or query block", tok)
      self:advance()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "when" then
      self:error("'when' keyword found outside of a rule block", tok)
      self:advance()
    elseif tok.type == TOKEN.KEYWORD and tok.value == "then" then
      self:error("'then' keyword found outside of a rule block", tok)
      self:advance()
    else
      self:error(string.format("Unexpected top-level token '%s' — expected rule, declare, import, global, query, or function", tok.value), tok)
      self:advance()
    end
  end
end

function Parser:parse_annotation()
  self:advance() -- '@name'
  if self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")")
  end
end

-- package com.example.rules;
function Parser:parse_package()
  local pkg_tok = self:advance() -- 'package'
  if not self:parse_scoped_ident(false) then
    self:error("Expected package name after 'package'", pkg_tok)
    self:recover(";", "import", "global", "declare", "rule", "query", "function")
  end
  self:match(TOKEN.PUNCT, ";")
end

-- unit com.example.rules.PricingUnit;
function Parser:parse_unit()
  local unit_tok = self:advance() -- 'unit'
  if not self:parse_scoped_ident(false) then
    self:error("Expected unit name after 'unit'", unit_tok)
    self:recover(";", "import", "global", "declare", "rule", "query", "function")
  end
  self:match(TOKEN.PUNCT, ";")
end

-- import [static|function|accumulate] com.example.Model [funcName];
function Parser:parse_import()
  local imp_tok = self:advance() -- 'import'
  local is_acc = self:match(TOKEN.KEYWORD, "accumulate") ~= nil
  if not is_acc then
    self:match(TOKEN.KEYWORD, "static")
    self:match(TOKEN.KEYWORD, "function")
  end

  if not self:parse_scoped_ident(true) then
    self:error("Expected class or package name after 'import'", imp_tok)
    self:recover(";", "import", "global", "declare", "rule", "query", "function")
    self:match(TOKEN.PUNCT, ";")
    return
  end

  if is_acc then
    if not self:match_ident_like() then
      self:error("Expected accumulate function identifier after class name in 'import accumulate'", imp_tok)
    end
  end

  self:match(TOKEN.PUNCT, ";")
end

-- global java.util.List<String> myList;
function Parser:parse_global()
  local glob_tok = self:advance() -- 'global'
  local gtype = self:parse_type()
  if not gtype then
    self:error("Expected type name after 'global'", glob_tok)
    self:recover(";", "global", "declare", "rule", "query", "function")
    self:match(TOKEN.PUNCT, ";")
    return
  end

  -- Make sure the next token is the variable name and not a top-level keyword on the next line
  if self:check(TOKEN.PUNCT, ";") or self:check(TOKEN.EOF) or self:is_new_top_level_block() then
    self:error("Expected variable name after global type declaration", glob_tok)
  elseif not self:match_ident_like() then
    self:error("Expected variable name after global type declaration", self:current())
  end

  self:match(TOKEN.PUNCT, ";")
end

-- declare [trait|enum|window|entry-point] Name [extends Parent] ... end
function Parser:parse_declare()
  local decl_tok = self:advance() -- 'declare'

  -- 1. declare entry-point "Name" ... end
  if self:match(TOKEN.KEYWORD, "entry-point") then
    if not (self:match(TOKEN.STRING) or self:match_ident_like()) then
      self:error("Expected entry-point name after 'declare entry-point'", decl_tok)
    end
    while self:check(TOKEN.ANNOTATION) do
      self:parse_annotation()
    end
    self:match(TOKEN.PUNCT, ";")
    if not self:match(TOKEN.KEYWORD, "end") then
      self:error("Unclosed 'declare entry-point' block — missing 'end'", decl_tok)
    end
    self:match(TOKEN.PUNCT, ";")
    return
  end

  -- 2. declare window Name ... end
  if self:match(TOKEN.KEYWORD, "window") then
    local win_name = self:match_ident_like()
    if not win_name then
      self:error("Expected window name after 'declare window'", decl_tok)
    end
    while self:check(TOKEN.ANNOTATION) do
      self:parse_annotation()
    end
    self:parse_lhs_section(win_name and win_name.value or "<window>", "declare window", "end")
    if not self:match(TOKEN.KEYWORD, "end") then
      self:error("Unclosed 'declare window' block — missing 'end'", decl_tok)
    end
    self:match(TOKEN.PUNCT, ";")
    return
  end

  -- 3. declare enum Name ... end
  local is_enum = self:match(TOKEN.KEYWORD, "enum") ~= nil
  if not is_enum then
    self:match(TOKEN.KEYWORD, "trait")
  end

  local name_str = self:parse_scoped_ident(false)
  if not name_str then
    self:error("Expected type name after 'declare'", decl_tok)
    self:recover("end", "rule", "declare", "query", "function")
    self:match(TOKEN.KEYWORD, "end")
    return
  end

  -- Optional extends Parent1 [, Parent2 ...]
  if self:match(TOKEN.KEYWORD, "extends") then
    if not self:parse_scoped_ident(false) then
      self:error("Expected parent type name after 'extends'")
    else
      while self:match(TOKEN.PUNCT, ",") do
        if not self:parse_scoped_ident(false) then
          self:error("Expected parent type name after ',' in 'extends'")
          break
        end
      end
    end
  end

  -- If enum, parse enum constants up to ';' before fields
  if is_enum then
    while self:check(TOKEN.ANNOTATION) do
      self:parse_annotation()
    end
    while not self:check(TOKEN.EOF) and not self:is_standalone_end() do
      if self:is_ident_like(self:current()) then
        self:advance() -- constant name
        if self:check(TOKEN.PUNCT, "(") then
          self:skip_balanced("(", ")")
        end
        if self:match(TOKEN.PUNCT, ",") then
          -- next enum constant
        elseif self:match(TOKEN.PUNCT, ";") then
          break
        else
          break
        end
      else
        break
      end
    end
  end

  -- Parse annotations and field declarations until 'end'
  while not self:check(TOKEN.EOF) and not self:is_standalone_end() do
    local cur = self:current()

    if cur.type == TOKEN.ANNOTATION then
      self:parse_annotation()
    elseif cur.type == TOKEN.PUNCT and cur.value == ";" then
      self:advance()
    elseif self:is_new_top_level_block() then
      self:error(string.format("Unclosed 'declare %s' block — missing 'end' before '%s'", name_str, cur.value), decl_tok)
      return
    elseif self:is_ident_like(cur) then
      self:parse_field_declaration(name_str)
    else
      self:error(string.format("Unexpected token '%s' inside 'declare %s' — expected field declaration (name : Type)", cur.value, name_str), cur)
      self:advance()
    end
  end

  if not self:match(TOKEN.KEYWORD, "end") then
    self:error(string.format("Unclosed 'declare %s' block — missing 'end'", name_str), decl_tok)
  end
  self:match(TOKEN.PUNCT, ";")
end

-- fieldName : TypeName [= defaultValue] [@annotations] [;]
function Parser:parse_field_declaration(declare_name)
  local field_tok = self:advance() -- field name

  if not self:match(TOKEN.PUNCT, ":") then
    local next_tok = self:current()
    if self:is_ident_like(next_tok) then
      self:error(
        string.format("Missing ':' separator in field declaration — expected '%s : %s' (colon required between field name and type)", field_tok.value, next_tok.value),
        field_tok
      )
    else
      self:error(
        string.format("Expected ':' after field name '%s' in declare '%s'", field_tok.value, declare_name),
        field_tok
      )
      if self:is_standalone_end() or self:is_new_top_level_block() then
        return
      end
    end
  end

  local field_type = self:parse_type()
  if not field_type then
    self:error(string.format("Expected type after ':' for field '%s' in declare '%s'", field_tok.value, declare_name), field_tok)
    self:recover("end", ";")
    self:match(TOKEN.PUNCT, ";")
    return
  end

  -- Optional annotations before '='
  while self:check(TOKEN.ANNOTATION) do
    self:parse_annotation()
  end

  -- Optional default value: = expression
  if self:match(TOKEN.OPERATOR, "=") then
    local eq_tok = self:prev()
    if self:check(TOKEN.PUNCT, ";") or self:is_standalone_end() or self:check(TOKEN.EOF) then
      self:error(string.format("Expected default value expression after '=' for field '%s'", field_tok.value), eq_tok)
    else
      local paren_depth = 0
      local brace_depth = 0
      local bracket_depth = 0
      local ternary_depth = 0
      local consumed_any = false

      while not self:check(TOKEN.EOF) do
        local cur = self:current()
        if paren_depth == 0 and brace_depth == 0 and bracket_depth == 0 then
          if cur.type == TOKEN.PUNCT and cur.value == ";" then
            break
          elseif self:is_standalone_end() or self:is_new_top_level_block() then
            break
          elseif cur.type == TOKEN.ANNOTATION then
            break
          elseif consumed_any and ternary_depth == 0 and self:is_ident_like(cur)
                 and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == ":" then
            -- Next field declaration (name : Type)
            break
          elseif consumed_any and ternary_depth == 0 and self:is_at_line_start() then
            -- Check if expression continues across the newline via an operator/dot/colon
            local prev = self:prev()
            local prev_continues = prev and (DANGLING_OPERATORS[prev.value] or prev.value == "?" or prev.value == ":" or prev.value == "." or prev.value == ",")
            local cur_continues = DANGLING_OPERATORS[cur.value] or cur.value == "?" or cur.value == ":" or cur.value == "."
            if not prev_continues and not cur_continues then
              break
            end
          end
        end

        if cur.type == TOKEN.PUNCT then
          if cur.value == "(" then paren_depth = paren_depth + 1
          elseif cur.value == ")" then paren_depth = math.max(0, paren_depth - 1)
          elseif cur.value == "{" then brace_depth = brace_depth + 1
          elseif cur.value == "}" then brace_depth = math.max(0, brace_depth - 1)
          elseif cur.value == "[" then bracket_depth = bracket_depth + 1
          elseif cur.value == "]" then bracket_depth = math.max(0, bracket_depth - 1)
          elseif cur.value == ":" and ternary_depth > 0 then
            ternary_depth = ternary_depth - 1
          end
        elseif cur.type == TOKEN.OPERATOR and cur.value == "?" then
          ternary_depth = ternary_depth + 1
        end

        self:advance()
        consumed_any = true
      end
    end
  end

  -- Optional field annotations after type/default value (e.g. @key, @position(0))
  while self:check(TOKEN.ANNOTATION) do
    self:parse_annotation()
  end

  self:match(TOKEN.PUNCT, ";")
end

local FUNCTION_MODIFIERS = {
  ["public"] = true, ["private"] = true, ["protected"] = true,
  ["static"] = true, ["final"] = true, ["synchronized"] = true,
}

-- function [modifiers] [<T>] [ReturnType] name(params) { body }
function Parser:parse_function()
  local func_tok = self:advance() -- 'function'

  -- Optional Java modifiers (e.g. `function static boolean ...`)
  while FUNCTION_MODIFIERS[self:current().value] do
    self:advance()
  end

  -- Optional generic type parameter declaration (e.g. `function <T> T ...`)
  if self:check(TOKEN.OPERATOR, "<") then
    self:advance()
    local gdepth = 1
    while not self:check(TOKEN.EOF) and gdepth > 0 do
      if self:check(TOKEN.OPERATOR, "<") then gdepth = gdepth + 1
      elseif self:check(TOKEN.OPERATOR, ">") then gdepth = gdepth - 1
      elseif self:check(TOKEN.OPERATOR, ">>") then gdepth = math.max(0, gdepth - 2)
      end
      self:advance()
    end
  end

  -- Determine whether a return type is present before the function name:
  -- If current token is an identifier immediately followed by '(', it's an untyped function `function myFunc(...)`
  local func_name_tok = nil
  if self:is_ident_like(self:current()) and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "(" then
    func_name_tok = self:advance()
  else
    local ret_type = self:parse_type()
    if not ret_type then
      self:error("Expected return type or function name after 'function'", func_tok)
      self:recover("{", "rule", "declare", "query", "function")
      if self:check(TOKEN.PUNCT, "{") then
        local ob = self:advance()
        self:parse_code_block(ob, "function", "}")
        self:match(TOKEN.PUNCT, "}")
      end
      return
    end

    if self:check(TOKEN.PUNCT, "(") then
      self:error(string.format("Expected function name after return type '%s' in 'function' declaration", ret_type), self:current())
    else
      func_name_tok = self:match_ident_like()
      if not func_name_tok then
        self:error("Expected function name in 'function' declaration", self:current())
        self:recover("(", "{", "rule", "declare", "query", "function")
      end
    end
  end

  local func_name = func_name_tok and func_name_tok.value or "<anonymous>"

  -- Parameter list: ( ... )
  if not self:check(TOKEN.PUNCT, "(") then
    self:error(string.format("Expected '(' after function name '%s'", func_name), self:current())
    self:recover("{", "rule", "declare", "query", "function")
  else
    self:skip_balanced("(", ")", string.format("in parameter list of function '%s'", func_name))
  end

  -- Optional array brackets after parameter list: function String foo()[]
  while self:check(TOKEN.PUNCT, "[") and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "]" do
    self:advance()
    self:advance()
  end

  -- Optional `throws Exception1, Exception2`
  if self:current().value == "throws" then
    self:advance()
    self:parse_scoped_ident(false)
    while self:match(TOKEN.PUNCT, ",") do
      self:parse_scoped_ident(false)
    end
  end

  -- Function body: { ... }
  if not self:check(TOKEN.PUNCT, "{") then
    self:error(string.format("Expected '{' to start body of function '%s'", func_name), func_name_tok or func_tok)
    return
  end

  local open_brace = self:advance() -- consume '{'
  self:parse_code_block(open_brace, string.format("function '%s'", func_name), "}")
  if not self:match(TOKEN.PUNCT, "}") then
    self:error(string.format("Unclosed function '%s' — missing closing '}'", func_name), open_brace)
  end
  self:match(TOKEN.PUNCT, ";")
end

-- query "name" [(params)] ... end
function Parser:parse_query()
  local q_tok = self:advance() -- 'query'
  local name_tok = self:match(TOKEN.STRING) or self:match_ident_like()
  if not name_tok then
    if self:check(TOKEN.ERROR) then
      self:advance()
    else
      self:error("Expected query name after 'query'", q_tok)
    end
  end

  local query_name = name_tok and name_tok.value or "<unnamed>"

  while self:check(TOKEN.ANNOTATION) do
    self:parse_annotation()
  end

  if self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")", string.format("in parameter list of query '%s'", query_name))
  end

  while self:check(TOKEN.ANNOTATION) do
    self:parse_annotation()
  end

  -- Validate LHS patterns inside query until 'end'
  self:parse_lhs_section(query_name, "query", "end")

  if not self:match(TOKEN.KEYWORD, "end") then
    self:error(string.format("Query '%s' is missing closing 'end'", query_name), q_tok)
  end
  self:match(TOKEN.PUNCT, ";")
end

-- rule ("Name" | Name) [extends ("Parent" | Parent)] [attributes/annotations] when [LHS] then [RHS] end
function Parser:parse_rule()
  local rule_tok = self:advance() -- 'rule'

  local name_tok = self:match(TOKEN.STRING)
  if not name_tok then
    local cur = self:current()
    if self:is_ident_like(cur) and cur.value ~= "when" and cur.value ~= "then" and cur.value ~= "end" and cur.type ~= TOKEN.ATTRIBUTE then
      name_tok = self:advance()
      -- Check if user wrote multiple unquoted words on the same line (e.g. `rule My Unquoted Rule`)
      local extra_words = {}
      while not self:check(TOKEN.EOF) and self:current().line == name_tok.line
            and self:is_ident_like(self:current())
            and self:current().value ~= "extends"
            and self:current().value ~= "when"
            and self:current().value ~= "then"
            and self:current().value ~= "end"
            and self:current().value ~= "attributes"
            and self:current().type ~= TOKEN.ATTRIBUTE do
        table.insert(extra_words, self:advance().value)
      end
      if #extra_words > 0 then
        local full_unquoted = name_tok.value .. " " .. table.concat(extra_words, " ")
        self:error(
          string.format("Unquoted rule name cannot contain spaces — wrap it in double quotes: \"%s\"", full_unquoted),
          name_tok
        )
      end
    elseif cur.type == TOKEN.ERROR then
      -- Tokenizer already reported unterminated string literal
      self:advance()
    else
      self:error("Expected rule name after 'rule'", rule_tok)
      self:recover("when", "then", "end", "rule", "declare", "query", "function")
    end
  end

  local rule_name = name_tok and name_tok.value or "<unnamed>"

  -- Optional annotations before extends
  while self:check(TOKEN.ANNOTATION) do
    self:parse_annotation()
  end

  -- Optional extends "Parent Rule" or extends ParentRule
  if self:match(TOKEN.KEYWORD, "extends") then
    if not (self:match(TOKEN.STRING) or (self:is_ident_like(self:current()) and self:current().value ~= "when" and self:advance())) then
      if self:check(TOKEN.ERROR) then
        self:advance()
      else
        self:error(string.format("Expected parent rule name after 'extends' in rule '%s'", rule_name))
      end
    end
  end

  -- Optional `attributes :` prefix
  if self:current().value == "attributes" then
    self:advance()
    self:match(TOKEN.PUNCT, ":")
  end

  -- Rule attributes and annotations (can be interleaved in any order)
  while not self:check(TOKEN.EOF) do
    if self:check(TOKEN.ANNOTATION) then
      self:parse_annotation()
    elseif self:check(TOKEN.ATTRIBUTE) then
      self:parse_rule_attribute(rule_name)
      self:match(TOKEN.PUNCT, ",")
      self:match(TOKEN.PUNCT, ";")
    elseif self:check(TOKEN.PUNCT, ",") or self:check(TOKEN.PUNCT, ";") then
      self:advance()
    else
      break
    end
  end

  -- Expect 'when' (or report invalid/misspelled attribute before 'when')
  if not self:is_standalone_when() then
    local cur = self:current()
    if self:is_standalone_end() then
      self:error(string.format("Rule '%s' is missing 'when' and 'then' sections", rule_name), rule_tok)
      self:advance() -- consume 'end'
      self:match(TOKEN.PUNCT, ";")
      return
    elseif self:is_standalone_then() then
      self:error(string.format("Rule '%s' is missing 'when' section before 'then'", rule_name), cur)
    elseif self:is_new_top_level_block() then
      self:error(string.format("Rule '%s' is unclosed and missing 'when', 'then', and 'end'", rule_name), rule_tok)
      return
    else
      self:error(
        string.format("Expected 'when' keyword in rule '%s', but found '%s' — possible invalid or misspelled rule attribute", rule_name, cur.value),
        cur
      )
      -- Recover to 'when', 'then', 'end', or next top-level block
      while not self:check(TOKEN.EOF)
        and not self:is_standalone_when()
        and not self:is_standalone_then()
        and not self:is_standalone_end()
        and not self:is_new_top_level_block() do
        self:advance()
      end
    end
  end

  if self:is_standalone_when() then
    self:advance() -- consume 'when'
    self:match(TOKEN.PUNCT, ":") -- optional ':' after 'when'

    -- Parse and validate LHS patterns until 'then'
    self:parse_lhs_section(rule_name, "when", "then")
  end

  -- Expect 'then'
  if not self:is_standalone_then() then
    if self:is_standalone_end() then
      self:error(string.format("Rule '%s' is missing 'then' section", rule_name), rule_tok)
      self:advance() -- consume 'end'
      self:match(TOKEN.PUNCT, ";")
      return
    elseif self:is_new_top_level_block() or self:check(TOKEN.EOF) then
      self:error(string.format("Rule '%s' is missing 'then' and closing 'end'", rule_name), rule_tok)
      return
    end
  else
    self:advance() -- consume 'then'
    -- Optional named consequence `[label]` or `:` after `then`
    if self:check(TOKEN.PUNCT, "[") then
      self:skip_balanced("[", "]")
    end
    self:match(TOKEN.PUNCT, ":")
  end

  -- Parse and validate RHS Java/MVEL block until 'end'
  self:parse_rhs_section(rule_name, rule_tok)

  if not self:is_standalone_end() then
    self:error(string.format("Rule '%s' is missing closing 'end'", rule_name), rule_tok)
  else
    self:advance() -- consume 'end'
    self:match(TOKEN.PUNCT, ";")
  end
end

function Parser:parse_rule_attribute(rule_name)
  local attr = self:advance() -- attribute token
  local attr_name = attr.value

  -- Optional ':' after attribute name
  self:match(TOKEN.PUNCT, ":")

  local cur = self:current()

  -- 1. Optional-boolean attributes: no-loop, lock-on-active, auto-focus, refract, direct
  if OPTIONAL_BOOL_ATTRIBUTES[attr_name] then
    if self:match(TOKEN.BOOLEAN) then
      return
    elseif self:check(TOKEN.PUNCT, "(") then
      self:skip_balanced("(", ")", string.format("in '%s' attribute", attr_name))
      return
    elseif cur.line > attr.line or cur.type == TOKEN.ATTRIBUTE or cur.type == TOKEN.ANNOTATION
           or self:is_standalone_when() or (cur.type == TOKEN.PUNCT and (cur.value == "," or cur.value == ";")) then
      -- Omitting boolean value defaults to `true` in Drools
      return
    else
      self:error(
        string.format("Invalid value '%s' for boolean rule attribute '%s' in rule '%s' — expected 'true' or 'false'", cur.value, attr_name, rule_name),
        cur
      )
      self:advance()
      return
    end
  end

  -- 2. Check if required attribute value is missing
  if self:check(TOKEN.EOF) or self:is_standalone_when() or self:is_standalone_then()
     or self:is_standalone_end() or self:check(TOKEN.ATTRIBUTE) or self:check(TOKEN.ANNOTATION) then
    self:error(string.format("Rule attribute '%s' in rule '%s' is missing its value", attr_name, rule_name), attr)
    return
  end

  -- 3. Parenthesized attribute value (e.g. timer(int: 30s 10s), salience($p + 10), enabled(true))
  if self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")", string.format("in '%s' attribute of rule '%s'", attr_name, rule_name))
    return
  end

  -- 4. String attributes: agenda-group, ruleflow-group, activation-group, dialect, date-effective, date-expires
  if STRING_ATTRIBUTES[attr_name] then
    if not self:match(TOKEN.STRING) then
      if self:check(TOKEN.ERROR) then
        self:advance()
      else
        self:error(
          string.format("Rule attribute '%s' in rule '%s' requires a quoted string value, but found '%s'", attr_name, rule_name, cur.value),
          cur
        )
        self:advance()
      end
    end
    return
  end

  -- 5. `calendars`: one or more comma-separated strings
  if attr_name == "calendars" then
    if not self:match(TOKEN.STRING) then
      self:error(string.format("Rule attribute 'calendars' in rule '%s' requires quoted string value(s)", rule_name), cur)
      self:advance()
      return
    end
    while self:check(TOKEN.PUNCT, ",") and self:peek(1).type == TOKEN.STRING do
      self:advance() -- ','
      self:advance() -- STRING
    end
    return
  end

  -- 6. `salience` / `duration` / `timer` / `enabled`:
  -- Support optional unary +/- before number, bound variables, booleans, strings, or inline expressions
  if self:check(TOKEN.OPERATOR, "-") or self:check(TOKEN.OPERATOR, "+") then
    self:advance()
  end

  if self:match(TOKEN.NUMBER) or self:match(TOKEN.BOOLEAN) or self:match(TOKEN.STRING)
     or self:match(TOKEN.BOUND_VAR) or self:match_ident_like() then
    -- Consume any remaining tokens on the same line that belong to an inline expression (e.g. `salience 10 + $bonus`)
    while not self:check(TOKEN.EOF) and self:current().line == attr.line
          and not self:check(TOKEN.ATTRIBUTE) and not self:check(TOKEN.ANNOTATION)
          and not self:is_standalone_when() and not self:check(TOKEN.PUNCT, ",") and not self:check(TOKEN.PUNCT, ";") do
      if self:check(TOKEN.PUNCT, "(") then
        self:skip_balanced("(", ")")
      else
        self:advance()
      end
    end
    return
  end

  self:error(string.format("Invalid value '%s' for rule attribute '%s' in rule '%s'", cur.value, attr_name, rule_name), cur)
  self:advance()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LHS ('when' and 'query') VALIDATOR
-- ═══════════════════════════════════════════════════════════════════════════

local LHS_CONDITIONAL_KEYWORDS = {
  ["and"] = true, ["or"] = true, ["not"] = true, ["exists"] = true, ["forall"] = true,
}

local LHS_CLAUSE_KEYWORDS = {
  ["eval"] = true, ["accumulate"] = true, ["acc"] = true, ["collect"] = true, ["groupby"] = true,
}

local RHS_ONLY_ACTIONS = {
  ["insert"] = true, ["insertLogical"] = true, ["modify"] = true,
  ["update"] = true, ["retract"] = true, ["delete"] = true,
}

--- Parse `over window:time(...)`, `over window:length(...)`, or `over WindowName`
function Parser:parse_over_clause(block_name, section_label)
  local over_tok = self:advance() -- 'over'
  if self:current().value == "window" and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == ":" then
    self:advance() -- 'window'
    self:advance() -- ':'
    local win_type = self:match_ident_like()
    if not win_type then
      self:error(string.format("Expected window type ('time' or 'length') after 'window:' in '%s' of '%s'", section_label, block_name), over_tok)
      return
    end
    if self:check(TOKEN.PUNCT, "(") then
      self:skip_balanced("(", ")", string.format("in 'over window:%s(...)' of '%s'", win_type.value, block_name))
    else
      self:error(string.format("Expected '(' after 'window:%s' in '%s' of '%s'", win_type.value, section_label, block_name), win_type)
    end
  elseif self:is_ident_like(self:current()) then
    self:advance() -- custom declared window name
    if self:check(TOKEN.PUNCT, "(") then
      self:skip_balanced("(", ")")
    end
  else
    self:error(string.format("Expected 'window:time(...)', 'window:length(...)', or window name after 'over' in '%s' of '%s'", section_label, block_name), over_tok)
  end
end

--- Parse `from entry-point "..."`, `from accumulate(...)`, `from collect(...)`, or `from <expression>`
function Parser:parse_from_clause(block_name, section_label)
  local from_tok = self:advance() -- 'from'

  if self:match(TOKEN.KEYWORD, "entry-point") then
    if not (self:match(TOKEN.STRING) or self:match_ident_like()) then
      self:error(string.format("Expected stream name after 'from entry-point' in '%s' of '%s'", section_label, block_name), from_tok)
    end
    return
  end

  if self:check(TOKEN.KEYWORD, "accumulate") or self:check(TOKEN.KEYWORD, "acc") or self:check(TOKEN.KEYWORD, "collect") then
    local kw = self:advance()
    if self:check(TOKEN.PUNCT, "(") then
      self:skip_balanced("(", ")", string.format("in 'from %s(...)' of '%s'", kw.value, block_name))
    else
      self:error(string.format("Expected '(' after 'from %s' in '%s' of '%s'", kw.value, section_label, block_name), kw)
    end
    return
  end

  if self:check(TOKEN.EOF) or self:is_standalone_then() or self:is_standalone_end() or self:is_new_top_level_block() then
    self:error(string.format("Expected source expression after 'from' in '%s' of '%s'", section_label, block_name), from_tok)
    return
  end

  -- Consume primary expression and any chained `.prop`, `?.prop`, `(args)`, `[idx]`
  if self:current().value == "new" then
    self:advance()
    self:parse_type()
  elseif self:check(TOKEN.BOUND_VAR) or self:is_ident_like(self:current()) or self:check(TOKEN.STRING) or self:check(TOKEN.NUMBER) then
    self:advance()
  elseif self:check(TOKEN.PUNCT, "(") then
    self:skip_balanced("(", ")")
  elseif self:check(TOKEN.PUNCT, "[") then
    self:skip_balanced("[", "]")
  else
    self:advance()
  end

  while not self:check(TOKEN.EOF) do
    local cur = self:current()
    if cur.type == TOKEN.PUNCT and (cur.value == "." or cur.value == "?." or cur.value == "!." or cur.value == "::") then
      self:advance()
      self:match_ident_like()
    elseif cur.type == TOKEN.PUNCT and cur.value == "(" then
      self:skip_balanced("(", ")", string.format("in 'from' expression of '%s'", block_name))
    elseif cur.type == TOKEN.PUNCT and cur.value == "[" then
      self:skip_balanced("[", "]", string.format("in 'from' expression of '%s'", block_name))
    else
      break
    end
  end
end

--- Parse OOPath segment or expression: `/orders[ status == "OPEN" ]/items#SubType[ price > 10 ]`
function Parser:parse_oopath(block_name, section_label)
  while self:check(TOKEN.OPERATOR, "/")
        or (self:check(TOKEN.OPERATOR, "?") and self:peek(1).type == TOKEN.OPERATOR and self:peek(1).value == "/")
        or self:check(TOKEN.PUNCT, ".") do
    if self:check(TOKEN.OPERATOR, "?") then
      self:advance() -- '?'
    end
    self:advance() -- '/' or '.'
    self:match_ident_like()
    -- Optional inline cast `#Type` or `#org.domain.Type`
    while self:check(TOKEN.PUNCT, "#") do
      self:advance() -- '#'
      self:parse_scoped_ident(false)
    end
    -- Note: we do NOT call skip_balanced here on '[' or '(' so that `parse_lhs_section`
    -- validates constraints, operators, and balanced brackets inside `/path[...]`!
    if not (self:check(TOKEN.OPERATOR, "/")
            or (self:check(TOKEN.OPERATOR, "?") and self:peek(1).value == "/")
            or self:check(TOKEN.PUNCT, ".")) then
      break
    end
  end
end

--- Parse and validate LHS section ('when' in rule, or body of 'query' / 'declare window')
function Parser:parse_lhs_section(block_name, section_label, stop_keyword)
  local delim_stack = {} -- stack of { open, close, tok, is_constraint_container, is_boolean_group }

  local function inside_constraint_container()
    for i = #delim_stack, 1, -1 do
      if delim_stack[i].is_constraint_container then
        return true
      end
    end
    return false
  end

  while not self:check(TOKEN.EOF) do
    local cur = self:current()
    local depth = #delim_stack

    -- Check stopping conditions at depth 0
    if depth == 0 then
      if stop_keyword == "then" and self:is_standalone_then() then
        break
      elseif stop_keyword == "end" and self:is_standalone_end() then
        break
      elseif stop_keyword == "then" and self:is_standalone_end() then
        -- Hit 'end' while looking for 'then' (missing 'then' section!)
        break
      elseif self:is_new_top_level_block() then
        break
      elseif self:is_standalone_when() then
        self:error(string.format("Duplicate 'when' keyword in %s '%s'", section_label, block_name), cur)
        self:advance()
        goto continue
      end
    end

    -- Track balanced delimiters: (), {}, []
    if cur.type == TOKEN.PUNCT then
      if cur.value == "(" then
        -- Check for invalid leading binary operator right after '(' (allows relational operators in `age ((> 30 && < 40))`)
        local next_tok = self:peek(1)
        if INVALID_AFTER_OPEN_PAREN[next_tok.value] then
          self:error(string.format("Unexpected operator '%s' after '(' in '%s' section of '%s'", next_tok.value, section_label, block_name), next_tok)
        end
        local prev = self:prev()
        local is_constraint_container = (depth == 0)
          and prev ~= nil
          and self:is_ident_like(prev)
          and not LHS_CONDITIONAL_KEYWORDS[prev.value]
          and not LHS_CLAUSE_KEYWORDS[prev.value]
          and prev.value ~= "if"
        local is_boolean_group = inside_constraint_container()
          and prev ~= nil
          and (prev.value == "(" or prev.value == "[" or prev.value == "," or prev.value == "&&" or prev.value == "||" or prev.value == "!")
        table.insert(delim_stack, {
          open = "(",
          close = ")",
          tok = cur,
          is_constraint_container = is_constraint_container,
          is_boolean_group = is_boolean_group,
        })
        self:advance()
        goto continue
      elseif cur.value == "{" then
        table.insert(delim_stack, { open = "{", close = "}", tok = cur })
        self:advance()
        goto continue
      elseif cur.value == "[" then
        local prev = self:prev()
        local is_constraint_container = (prev ~= nil and self:is_ident_like(prev) and prev.value ~= "str" and prev.value ~= "do" and prev.value ~= "break" and not KEYWORDS[prev.value])
        table.insert(delim_stack, {
          open = "[",
          close = "]",
          tok = cur,
          is_constraint_container = is_constraint_container,
        })
        self:advance()
        goto continue
      elseif cur.value == ")" or cur.value == "}" or cur.value == "]" then
        -- Check if previous token before closing delimiter was a dangling operator or ':'
        local prev = self:prev()
        local is_dangling_gt = prev and prev.value == ">" and cur.value == ")"
          and (not self:peek(-2) or (self:peek(-2).type ~= TOKEN.TYPE_IDENT and self:peek(-2).value ~= ">" and self:peek(-2).value ~= "?" and self:peek(-2).value ~= "]"))
        if prev and (DANGLING_OPERATORS[prev.value] or is_dangling_gt or (prev.type == TOKEN.PUNCT and prev.value == ".")) then
          self:error(
            string.format("Incomplete expression before '%s' — expected operand after '%s'", cur.value, prev.value),
            prev
          )
        elseif prev and prev.type == TOKEN.PUNCT and prev.value == ":" then
          self:error(string.format("Expected pattern or field name after ':' before '%s'", cur.value), prev)
        end

        if #delim_stack == 0 then
          self:error(string.format("Unmatched closing '%s' in '%s' section of '%s'", cur.value, section_label, block_name), cur)
        else
          local top = delim_stack[#delim_stack]
          if top.close == cur.value then
            table.remove(delim_stack)
          else
            self:error(
              string.format("Mismatched delimiter '%s' (expected '%s' to close '%s' from line %d)", cur.value, top.close, top.open, top.tok.line),
              cur
            )
            table.remove(delim_stack)
          end
        end
        self:advance()
        goto continue
      end
    end

    -- Inside constraints/expressions (depth > 0): validate operator sequences
    if depth > 0 then
      local top_delim = delim_stack[#delim_stack]
      if cur.type == TOKEN.PUNCT and cur.value == "," then
        local prev = self:prev()
        local next_tok = self:peek(1)
        if top_delim and top_delim.is_boolean_group then
          self:error("Comma ',' is not valid inside a parenthesized boolean expression — use '&&' or '||' instead", cur)
        end
        local is_dangling_gt = prev and prev.value == ">"
          and (not self:peek(-2) or (self:peek(-2).type ~= TOKEN.TYPE_IDENT and self:peek(-2).value ~= ">" and self:peek(-2).value ~= "?" and self:peek(-2).value ~= "]"))
        if prev and (DANGLING_OPERATORS[prev.value] or is_dangling_gt or (prev.type == TOKEN.PUNCT and prev.value == ":")) then
          self:error(string.format("Incomplete constraint before ',' — expected operand after '%s'", prev.value), prev)
        end
        if LEADING_BINARY_OPERATORS[next_tok.value] then
          self:error(string.format("Unexpected operator '%s' after ',' in constraint", next_tok.value), next_tok)
        end
      elseif LEADING_BINARY_OPERATORS[cur.value] then
        local next_tok = self:peek(1)
        -- Allow `&& < 40` or `|| > 20` (abbreviated combined relation condition in Drools)
        local is_abbrev_rel = (cur.value == "&&" or cur.value == "||") and RELATIONAL_OPERATORS[next_tok.value]
        local is_generic_shift = (cur.value == ">" and next_tok.value == ">")
        if LEADING_BINARY_OPERATORS[next_tok.value] and not is_abbrev_rel and not is_generic_shift then
          self:error(string.format("Unexpected consecutive operator '%s' after '%s'", next_tok.value, cur.value), next_tok)
        end
      end
      self:advance()
      goto continue
    end

    -- At depth == 0 in LHS:
    -- 1. Check for RHS-only actions accidentally placed in 'when' (e.g. modify, insert, retract, delete, update)
    if cur.type == TOKEN.KEYWORD and RHS_ONLY_ACTIONS[cur.value] and self:peek(1).value == "(" then
      local prev = self:prev()
      if not prev or prev.value ~= "." then
        self:error(
          string.format("RHS action '%s(...)' is not valid inside '%s' condition block of '%s' (belongs in 'then' section)", cur.value, section_label, block_name),
          cur
        )
      end
    end

    -- 2. Handle `from`, `over`, OOPath `/...` or `?/..`, and `;` at depth 0
    if cur.value == "from" then
      self:parse_from_clause(block_name, section_label)
      goto continue
    elseif cur.value == "over" then
      self:parse_over_clause(block_name, section_label)
      goto continue
    elseif (cur.type == TOKEN.OPERATOR and cur.value == "/")
           or (cur.type == TOKEN.OPERATOR and cur.value == "?" and self:peek(1).type == TOKEN.OPERATOR and self:peek(1).value == "/") then
      self:parse_oopath(block_name, section_label)
      goto continue
    elseif cur.type == TOKEN.OPERATOR and cur.value == "?" then
      -- Query call `?queryName(...)`
      self:advance()
      goto continue
    elseif cur.type == TOKEN.PUNCT and cur.value == "#" then
      -- Inline cast on OOPath `/persons # Student`
      self:advance()
      self:parse_scoped_ident(false)
      goto continue
    elseif cur.type == TOKEN.ANNOTATION then
      self:parse_annotation()
      goto continue
    elseif cur.type == TOKEN.PUNCT and cur.value == ";" then
      self:advance()
      goto continue
    end

    -- 3. Bound variable at depth 0: `$var : FactType(...)` or `var : /path[...]` or `$var := ...`
    if cur.type == TOKEN.BOUND_VAR
       or (self:is_ident_like(cur) and not LHS_CONDITIONAL_KEYWORDS[cur.value]
           and ((self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == ":")
                or (self:peek(1).type == TOKEN.OPERATOR and self:peek(1).value == ":="))) then
      local var_tok = self:advance()
      if self:match(TOKEN.PUNCT, ":") or self:match(TOKEN.OPERATOR, ":=") then
        if self:is_standalone_then() or self:is_standalone_end() or self:check(TOKEN.EOF) then
          self:error(string.format("Expected fact pattern after '%s :' in '%s' section of '%s'", var_tok.value, section_label, block_name), var_tok)
        end
      else
        -- e.g. `$user.setStatus("ACTIVE");` or `$x = 1;` placed in `when`
        self:error(
          string.format("Unexpected statement or missing ':' after bound variable '%s' in '%s' condition block of '%s'", var_tok.value, section_label, block_name),
          var_tok
        )
        while not self:check(TOKEN.EOF) and self:current().line == var_tok.line
              and not self:is_standalone_then() and not self:is_standalone_end() do
          self:advance()
        end
      end
      goto continue
    end

    -- 4. Fact Type, Query Call, or Conditional Element at depth 0:
    if self:is_ident_like(cur) then
      local kw = cur.value
      if LHS_CONDITIONAL_KEYWORDS[kw] or LHS_CLAUSE_KEYWORDS[kw]
         or kw == "do" or kw == "break" or kw == "if" or kw == "else" then
        self:advance()
        goto continue
      end

      -- Parse potentially qualified type or method call (e.g. `Customer(...)`, `com.pkg.Customer(...)`, or invalid `System.out.println(...)`)
      local start_tok = cur
      local name_str = self:parse_scoped_ident(false)
      local after_type = self:current()

      if after_type.type == TOKEN.PUNCT and after_type.value == "(" then
        -- Check if `name_str` is a dotted Java method call (e.g. `System.out.println(...)`, `logger.info(...)`)
        local last_seg = name_str:match("%.([^%.]+)$")
        if last_seg and last_seg:sub(1, 1):match("[a-z]") then
          self:error(
            string.format("Java statement '%s(...)' is not valid in '%s' condition block of '%s' (missing 'then' keyword?)", name_str, section_label, block_name),
            start_tok
          )
        end
      elseif after_type.type == TOKEN.ANNOTATION then
        -- metadata on pattern
      else
        self:error(
          string.format("Expected '(' after fact type '%s' in '%s' condition of '%s' (e.g. %s(...))", name_str, section_label, block_name, name_str),
          start_tok
        )
      end
      goto continue
    end

    self:advance()
    ::continue::
  end

  -- Report any unclosed delimiters in LHS
  for i = #delim_stack, 1, -1 do
    local unclosed = delim_stack[i]
    self:error(
      string.format("Unmatched opening '%s' in '%s' section of '%s' — missing closing '%s'", unclosed.open, section_label, block_name, unclosed.close),
      unclosed.tok
    )
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RHS ('then') AND JAVA/MVEL CODE BLOCK VALIDATOR
-- ═══════════════════════════════════════════════════════════════════════════

--- Parse and validate the RHS ('then') section of a rule until standalone 'end'
function Parser:parse_rhs_section(rule_name, rule_tok)
  self:parse_code_block(rule_tok, string.format("'then' section of rule '%s'", rule_name), "end")
end

--- Parse and validate a Java / MVEL / Drools RHS code block until `stop_token` ("end" or "}")
function Parser:parse_code_block(start_tok, context_label, stop_token)
  local delim_stack = {} -- stack of { open, close, tok }

  while not self:check(TOKEN.EOF) do
    local cur = self:current()
    local depth = #delim_stack

    -- 1. Check block termination and structural errors at depth 0
    if depth == 0 then
      if stop_token == "end" and self:is_standalone_end() then
        break
      elseif stop_token == "}" and cur.type == TOKEN.PUNCT and cur.value == "}" then
        break
      elseif self:is_new_top_level_block() then
        break
      elseif stop_token == "end" and self:is_standalone_when() then
        self:error(string.format("Unexpected 'when' keyword inside %s", context_label), cur)
        self:advance()
        goto continue
      elseif stop_token == "end" and self:is_standalone_then() then
        -- Allow `then[label]` named consequences, flag bare duplicate `then`
        if self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "[" then
          self:advance() -- 'then'
          self:skip_balanced("[", "]")
        else
          self:error(string.format("Duplicate 'then' keyword inside %s", context_label), cur)
          self:advance()
        end
        goto continue
      end
    end

    -- 2. Validate Drools `modify($target) { ... }` construct in RHS
    if cur.type == TOKEN.KEYWORD and cur.value == "modify" then
      local prev = self:prev()
      local is_member = prev and (prev.value == "." or prev.value == "?." or prev.value == "::")
      if not is_member and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "{" then
        self:error(string.format("Missing target fact in 'modify' statement in %s — expected 'modify($fact) { ... }'", context_label), cur)
      elseif not is_member and self:peek(1).type == TOKEN.PUNCT and self:peek(1).value == "("
             and self:peek(2).type == TOKEN.PUNCT and self:peek(2).value == ")" then
        self:error(string.format("Empty target in 'modify()' statement in %s — expected 'modify($fact) { ... }'", context_label), cur)
      end
    end

    -- 3. Track balanced delimiters (), {}, []
    if cur.type == TOKEN.PUNCT then
      if cur.value == "(" then
        local next_tok = self:peek(1)
        if LEADING_BINARY_OPERATORS[next_tok.value] then
          self:error(string.format("Unexpected operator '%s' after '(' in %s", next_tok.value, context_label), next_tok)
        end
        table.insert(delim_stack, { open = "(", close = ")", tok = cur })
        self:advance()
        goto continue
      elseif cur.value == "{" then
        table.insert(delim_stack, { open = "{", close = "}", tok = cur })
        self:advance()
        goto continue
      elseif cur.value == "[" then
        table.insert(delim_stack, { open = "[", close = "]", tok = cur })
        self:advance()
        goto continue
      elseif cur.value == ")" or cur.value == "}" or cur.value == "]" then
        local prev = self:prev()
        if prev and (DANGLING_OPERATORS[prev.value] or (prev.type == TOKEN.PUNCT and prev.value == ".")) then
          -- Allow `{}` or `init( int x = 0; )` where prev is `;`, `{`, etc., but flag `foo(a + )` or `obj.)`
          self:error(
            string.format("Incomplete expression before '%s' in %s — expected operand after '%s'", cur.value, context_label, prev.value),
            prev
          )
        end

        if #delim_stack == 0 then
          self:error(string.format("Unmatched closing '%s' in %s", cur.value, context_label), cur)
        else
          local top = delim_stack[#delim_stack]
          if top.close == cur.value then
            table.remove(delim_stack)
          else
            self:error(
              string.format("Mismatched delimiter '%s' in %s (expected '%s' to close '%s' from line %d)", cur.value, context_label, top.close, top.open, top.tok.line),
              cur
            )
            table.remove(delim_stack)
          end
        end
        self:advance()
        goto continue
      elseif cur.value == ";" then
        local prev = self:prev()
        if prev and (DANGLING_OPERATORS[prev.value] or (prev.type == TOKEN.PUNCT and prev.value == ".")) then
          self:error(
            string.format("Incomplete statement before ';' in %s — expected expression after '%s'", context_label, prev.value),
            prev
          )
        end
      end
    end

    self:advance()
    ::continue::
  end

  -- Report any unclosed delimiters
  for i = #delim_stack, 1, -1 do
    local unclosed = delim_stack[i]
    self:error(
      string.format("Unmatched opening '%s' in %s — missing closing '%s'", unclosed.open, context_label, unclosed.close),
      unclosed.tok
    )
  end
end

--- Skip balanced delimiters (parens, braces, brackets)
function Parser:skip_balanced(open, close, context)
  local open_tok = self:match(TOKEN.PUNCT, open)
  if not open_tok then return end
  local depth = 1
  while not self:check(TOKEN.EOF) and depth > 0 do
    local cur = self:current()
    if cur.type == TOKEN.PUNCT and cur.value == open then
      depth = depth + 1
    elseif cur.type == TOKEN.PUNCT and cur.value == close then
      depth = depth - 1
      if depth == 0 then
        self:advance()
        return
      end
    elseif self:is_new_top_level_block() then
      break
    end
    self:advance()
  end
  local suffix = context and (" " .. context) or ""
  self:error(string.format("Unmatched '%s'%s — missing closing '%s'", open, suffix, close), open_tok)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════

M.tokenize = tokenize
M.Parser = Parser

--- Parse a DRL source string and return list of syntax errors
---@param source string
---@return table[] errors Array of { message, line, col }
function M.parse_source(source)
  local tokens, tokenizer_errors = tokenize(source)
  local parser = Parser.new(tokens, tokenizer_errors)
  parser:parse()
  return parser.errors
end

--- Perform grammar-aware linting on a specific buffer
---@param bufnr number Buffer number
function M.lint(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "drools" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local source = table.concat(lines, "\n")

  local errors = M.parse_source(source)

  -- Convert errors to Neovim diagnostics
  local diagnostics = {}
  for _, err in ipairs(errors) do
    table.insert(diagnostics, {
      bufnr = bufnr,
      lnum = math.max(0, (err.line or 1) - 1), -- 0-indexed
      col = math.max(0, (err.col or 1) - 1),   -- 0-indexed
      severity = vim.diagnostic.severity.ERROR,
      message = err.message,
      source = "drools-parser",
    })
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

local attached_buffers = {}
local current_mode = "insert_leave"

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
    if current_mode == "on_save" then
      return
    end
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

  -- Attach native buffer line listener
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

function M.set_mode(mode, silent)
  mode = (mode or "insert_leave"):lower()
  if mode == "insert_leave" then
    current_mode = "insert_leave"
    vim.diagnostic.config({ update_in_insert = false }, ns)
    if not silent then
      vim.notify("Drools Linter Mode set to 'insert_leave' (diagnostics update when exiting Insert mode)", vim.log.levels.INFO)
    end
  elseif mode == "live" then
    current_mode = "live"
    vim.diagnostic.config({ update_in_insert = true }, ns)
    if not silent then
      vim.notify("Drools Linter Mode set to 'live' (diagnostics update DURING Insert mode as you type)", vim.log.levels.INFO)
    end
  elseif mode == "on_save" then
    current_mode = "on_save"
    vim.diagnostic.config({ update_in_insert = false }, ns)
    if not silent then
      vim.notify("Drools Linter Mode set to 'on_save' (diagnostics update ONLY on file save)", vim.log.levels.INFO)
    end
  else
    vim.notify("Invalid linter mode: " .. tostring(mode) .. ". Valid options: 'insert_leave', 'live', 'on_save'", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}
  local mode = opts.mode or "insert_leave"
  M.set_mode(mode, true)

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

  -- Lint on InsertLeave and BufWritePost
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufWritePost" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.bo[args.buf].filetype == "drools" then
        if args.event == "BufWritePost" or current_mode ~= "on_save" then
          M.lint(args.buf)
        end
      end
    end,
  })
end

return M
