# Specification for `drools.nvim` (Drools Neovim Plugin)

## 1. Overview & Objectives

`drools.nvim` is a Neovim plugin written in Lua to provide a rich development environment for **Drools Rule Language (`.drl`)** and **Domain Specific Language (`.dsl`)** files.

### Key Features
- **Filetype Detection**: Automatically detect `.drl` and `.dsl` files.
- **Tree-Sitter Primary Syntax Highlighting**: Grammar-driven highlighting for Drools keywords, CEP operators, accumulate functions, pattern bindings, fact types, RHS embedded Java, and annotations.
- **Vim Regex Fallback**: Native regex syntax file (`syntax/drools.vim`) for environments without a compiled Tree-sitter parser.
- **Syntax Checking & Diagnostics**: 3-tier diagnostic system:
  1. Tree-sitter AST parse error nodes (`(ERROR)` & `(MISSING)`).
  2. Pure Lua structural syntax checker (`lua/drools/linter.lua`).
  3. Drools Language Server (LSP) integration (`lua/drools/lsp.lua`).
- **Formal Tree-Sitter Grammar**: [`tree-sitter-drools/grammar.js`](file:///home/pk/git/drools-neovim/tree-sitter-drools/grammar.js) derived from official Apache KIE Drools ANTLR 4 DRL parser specifications.
- **Editing Enhancements**: Smart indentation, comment configuration, rule folding, snippet templates, symbol navigation, and test runner.
- **Plugin Health Checks**: `:checkhealth drools` module verifying version, Tree-sitter engine, LSP, and linter setup.

---

## 2. Directory Structure

```
drools-neovim/
├── ftdetect/
│   └── drools.lua            # Dynamic filetype registration (.drl, .dsl)
├── ftplugin/
│   └── drools.lua            # Buffer-local options, keymaps, comments
├── syntax/
│   └── drools.vim            # Legacy Vim regex syntax highlighting (fallback)
├── indent/
│   └── drools.lua            # Custom rule-based indentation logic
├── tree-sitter-drools/
│   ├── grammar.js            # Official ANTLR4-derived Tree-sitter grammar
│   └── package.json          # Tree-sitter CLI package manifest
├── queries/
│   └── drools/               # Tree-sitter queries
│       ├── highlights.scm    # Highlight scope captures
│       ├── folds.scm         # Rule & block folding queries
│       └── indents.scm       # Indentation queries
├── lua/
│   └── drools/
│       ├── init.lua          # Main plugin entrypoint & setup()
│       ├── config.lua        # Default options and user config merge
│       ├── treesitter.lua    # Tree-sitter primary driver & AST diagnostics
│       ├── lsp.lua           # Drools LSP server launcher with path expansion
│       ├── linter.lua        # Pure Lua structural syntax validator
│       ├── navigation.lua    # Symbols outline & definition jump
│       ├── formatter.lua     # Buffer auto-formatter
│       ├── runner.lua        # Test suite execution runner
│       ├── snippets.lua      # Snippet generator / LuaSnip loader
│       └── health.lua        # :checkhealth drools diagnostic check
└── snippets/
    └── drools.json           # VSCode format snippets for nvim-cmp / LuaSnip
```

---

## 3. Detailed Specifications

### 3.1 Filetype Detection (`ftdetect/drools.lua`)
Register `.drl` and `.dsl` extensions cleanly using standard Neovim API:
```lua
vim.filetype.add({
  extension = {
    drl = "drools",
    dsl = "drools",
  },
})
```

### 3.2 Buffer Configuration (`ftplugin/drools.lua`)
Set buffer-local options when a Drools file is opened:
- `commentstring`: `// %s` (or `/* %s */`)
- `comments`: `s1:/*,mb:*,ex:*/,://`
- `shiftwidth`, `tabstop`, `expandtab`: 4 spaces
- `foldmethod`, `foldexpr`: Tree-sitter foldexpr (`v:lua.vim.treesitter.foldexpr()`) or indent folding.

---

### 3.3 Syntax Highlighting Strategy
Dual-layer highlighting support with Tree-sitter as primary:

#### Strategy A: Tree-Sitter Integration (`queries/drools/highlights.scm`) - Primary
- **Grammar Node Mapping**: Target AST nodes produced by [`tree-sitter-drools/grammar.js`](file:///home/pk/git/drools-neovim/tree-sitter-drools/grammar.js):
  - `rule_declaration`, `fact_pattern`, `field_constraint`, `variable_binding`, `accumulate_function`, `operator`, `rhs_action`, `rhs_implicit`, `annotation`.

#### Strategy B: Regex-based Vim Syntax (`syntax/drools.vim`) - Fallback
- **Structure & Unit Keywords**: `package`, `import`, `global`, `function`, `query`, `declare`, `rule`, `when`, `then`, `end`, `unit`, `extends`.
- **Rule Attributes**: `salience`, `agenda-group`, `ruleflow-group`, `activation-group`, `lock-on-active`, `no-loop`, `auto-focus`, `enabled`, `dialect`, `duration`, `timer`, `calendars`, `date-effective`, `date-expires`, `refract`, `direct`.
- **LHS Conditional & Operators**: `and`, `or`, `not`, `exists`, `forall`, `eval`, `from`, `over`, `entry-point`, `accumulate`, `collect`, `matches`, `contains`, `memberOf`, `soundslike`, `in`, `excludes`.
- **Complex Event Processing (CEP)**: Temporal operators (`after`, `before`, `coincides`, `during`, `finishes`, `finishedby`, `meets`, `metby`, `overlaps`, `overlappedby`, `starts`, `startedby`), sliding windows (`window:time`, `window:length`), and temporal offsets (`[0s, 5m]`).
- **Accumulate Functions & Clauses**: Built-in functions (`sum`, `avg`, `min`, `max`, `count`, `collectList`, `collectSet`, `collectArray`), clause blocks (`init`, `action`, `reverse`, `result`).
- **Fact Types & Variables**: Fact class names (`Person(...)`), bound variables starting with `$` (`$p`), binding operator (`:`).
- **Data Types & Literals**: Strings (`"..."`, `'...'`), numbers (integers, floats, hex, type suffixes `L`/`f`/`d`), booleans (`true`, `false`), `null`.
- **Annotations**: General `@annotation` matching and known metadata (`@role`, `@timestamp`, `@duration`, `@expires`, `@key`, `@propertyChangeSupport`, `@format`, `@classReactive`, `@propertyReactive`).
- **RHS & Embedded Java/MVEL**: Built-in RHS actions (`insert`, `insertLogical`, `modify`, `update`, `retract`, `delete`), implicit objects (`drools`, `kcontext`, `entryPoints`, `channels`, `System`), embedded Java control flow keywords (`new`, `if`, `else`, `for`, `while`, `do`, `try`, `catch`, `finally`, `throw`, `return`, `instanceof`).
- **DSL Files**: Structural headers (`[when]`, `[then]`, `[keyword]`) and parameters (`{variable}`).

---

### 3.4 Syntax Checking & Diagnostics Architecture

1. **Tier 1: Tree-Sitter AST Parse Error Nodes (`lua/drools/treesitter.lua`)**
   - Queries `(ERROR)` and `(MISSING)` nodes from the syntax tree for exact line & column diagnostics.
2. **Tier 2: Pure Lua Structural Validator (`lua/drools/linter.lua`)**
   - Validates unclosed `rule`/`declare` blocks, `when`/`then` order, missing `package` header, and balanced parentheses.
3. **Tier 3: Drools Language Server (LSP) (`lua/drools/lsp.lua`)**
   - Integrates with Red Hat / KIE `drools-lsp-server.jar` or `jbang org.kie:drools-lsp-server:RELEASE`.
   - Supports path expansion (`~`) and `lspconfig` / native `vim.lsp.start`.

---

### 3.5 Editing Features

#### A. Indentation (`indent/drools.lua` & `queries/drools/indents.scm`)
Smart indent rules:
- Increase indent level after `rule ...`, `when`, `then`, `declare ...`, `query ...`.
- Decrease indent level at `when`, `then`, `end`.

#### B. Code Snippets (`snippets/drools.json` & `lua/drools/snippets.lua`)
Pre-packaged snippets for rapid rule creation:
- `rule`: Standard rule template with `when` and `then`.
- `rule-salience`: Rule with salience attribute.
- `declare`: Type declaration block (`declare ... end`).
- `query`: Query definition (`query ... end`).
- `global`: Global object import.

---

### 3.6 Interactive Definition Jump & Documentation Hover (`Ctrl+Click` / `<K>` / `gd`)

Providing an IDE-grade `Ctrl+Click` (`<C-LeftMouse>`), hover (`<K>` / `:DroolsHover`), and definition jump (`gd` / `:DroolsGotoDefinition`) workflow:

#### A. Architecture & Context Routing
1. **Syntax Keyword / Language Construct**:
   - When clicked or inspected on a Drools keyword (`salience`, `agenda-group`, `accumulate`, `after`, `window:time`, `modify`, `insert`, `entry-point`, `@role`, etc.):
   - Queries the offline embedded **Drools Specification Reference Database** ([`resources/drools_spec_docs.json`](file:///home/pk/git/drools-neovim/resources/drools_spec_docs.json)).
   - Renders a floating markdown hover window showing official documentation, syntax usage, and code examples.

2. **User Symbols (Fact Types, Bound Variables, Fields, Globals, Queries, Functions)**:
   - When clicked on a user-defined symbol (e.g. `Customer`, `$customer`, `membershipTier`, `alertService`):
   - **If LSP Attached**: Delegates directly to LSP `vim.lsp.buf.hover()` or `vim.lsp.buf.definition()`.
   - **If Offline/No LSP**: Performs AST/buffer resolution ([`lua/drools/navigation.lua`](file:///home/pk/git/drools-neovim/lua/drools/navigation.lua)) to jump to the declaration (`declare Customer ... end`, `$customer : Customer`, `global AlertService alertService`, `query "..."`, or `function ...`) and displays a preview popup.

---

## 4. Lua API & Configuration Interface

### Default Options (`lua/drools/config.lua`)
```lua
local M = {}

M.defaults = {
  treesitter = {
    enable = true,
    prefer_treesitter_folding = true,
    use_ast_linter = true,
  },
  highlight = {
    enable = true,
    use_treesitter = true,
    fallback_regex = true,
  },
  linter = {
    enable = true,
    on_save = true,
    on_change = false,
    use_treesitter_parser = true,
  },
  lsp = {
    enable = false,
    cmd = { "java", "-jar", "~/.local/share/drools/drools-lsp-server.jar" },
    filetypes = { "drools" },
    root_dir = nil,
  },
  snippets = {
    enable = true,
  },
}

return M
```

---

## 5. Implementation Roadmap

| Phase | Deliverable | Status | Description |
|---|---|---|---|
| **Phase 1** | Base Syntax & Filetype | ✅ Completed | Implemented `ftdetect`, `ftplugin`, and legacy `syntax/drools.vim`. |
| **Phase 2** | Tree-Sitter Grammar & Queries | ✅ Completed | Created `tree-sitter-drools/grammar.js` (from ANTLR4) and `queries/drools/highlights.scm`. |
| **Phase 3** | Indentation & Snippets | ✅ Completed | Added `indent/drools.lua` and `snippets/drools.json` for LuaSnip/cmp. |
| **Phase 4** | Diagnostic Linter & AST Checker | ✅ Completed | Integrated Tree-sitter error node parser and pure Lua linter in `lua/drools/linter.lua`. |
| **Phase 5** | LSP Client Setup | ✅ Completed | Built `lua/drools/lsp.lua` with path expansion for Drools Language Server integration. |
| **Phase 6** | Navigation, Format & Health Check | ✅ Completed | Implemented outline navigation, formatter, test runner, and `:checkhealth drools`. |
