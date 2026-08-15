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
│       ├── treesitter.lua    # Tree-sitter primary driver & parser integration
│       ├── lsp.lua           # Drools LSP server launcher with path expansion
│       ├── linter.lua        # Tokenizer + recursive descent parser for live syntax checking
│       ├── completion.lua    # Context-aware omni-completion provider (omnifunc / cmp)
│       ├── hover.lua         # Specification popup lookup & keyword documentation
│       ├── navigation.lua    # Symbols outline & definition jump
│       ├── agenda.lua        # Rule execution agenda priority inspector & infinite loop detector
│       ├── code_action.lua   # Quick-fix code actions menu
│       ├── textobjects.lua   # Structural text-objects (aR, iR, aW, iW, aT, iT, aD, iD)
│       ├── dsl.lua           # DSL mapping file parser and raw DRL expansion preview
│       ├── formatter.lua     # Buffer auto-formatter
│       ├── runner.lua        # Test suite execution runner
│       ├── snippets.lua      # Snippet generator / LuaSnip loader
│       └── health.lua        # :checkhealth drools diagnostic check
├── resources/
│   └── drools_spec_docs.json # Embedded specification reference database (30+ keywords)
└── snippets/
    └── drools.json           # VSCode format snippets for nvim-cmp / LuaSnip
```

---

## 3. Detailed Specifications & Implementation Status

### 3.1 Filetype Detection (`ftdetect/drools.lua`)
- ✅ **Completed**: Registers `.drl` and `.dsl` extensions automatically using Neovim API.

### 3.2 Buffer Configuration (`ftplugin/drools.lua`)
- ✅ **Completed**: Buffer-local options: `commentstring`, `shiftwidth = 4`, `tabstop = 4`, `expandtab = true`, foldexpr, and keymaps.

### 3.3 Syntax Highlighting & Tokenizer
- ✅ **Completed**: Dual-layer system. Tree-sitter primary grammar derived from Apache KIE ANTLR4 spec, with Vim regex fallback.

### 3.4 Interactive Live Syntax Checker (`lua/drools/linter.lua`)
- ✅ **Completed**: 2-phase compiler frontend (Tokenizer + Recursive Descent Parser) running live as you type (`TextChanged`, `TextChangedI`, `InsertLeave`) with 100ms debouncing. Catches unclosed strings, missing colons, misspelled attributes, unclosed blocks, and unbalanced parens/braces without requiring buffer saves.

### 3.5 Auto-Completion Provider (`lua/drools/completion.lua`)
- ✅ **Completed**: Context-aware `omnifunc` provider (`<C-x><C-o>` / `nvim-cmp`) matching keywords, rule attributes, declared fact types, bound variables (`$var`), and RHS actions.

### 3.6 Specification Documentation & Hover (`lua/drools/hover.lua`)
- ✅ **Completed**: Embedded database (`resources/drools_spec_docs.json`) covering 30+ keywords. Supports `<C-LeftMouse>`, `<K>`, `:DroolsHover`, and `:DroolsSpec <kw>` with tab completion and floating popup dismissal via `<Esc>` or `q`.

### 3.7 Rule Agenda & Priority Inspector (`lua/drools/agenda.lua`)
- ✅ **Completed**: `:DroolsAgenda` (`<leader>da`) ranks rules by `agenda-group` and `salience` priority while warning about infinite loop risks (`modify` without `no-loop`).

### 3.8 Quick-Fix Code Actions (`lua/drools/code_action.lua`)
- ✅ **Completed**: `:DroolsCodeAction` (`<leader>ca`) interactive menu for auto-inserting `end`, `no-loop true`, `package` headers, and toggling rule `enabled` state.

### 3.9 Structural Text-Objects (`lua/drools/textobjects.lua`)
- ✅ **Completed**: Non-conflicting uppercase text-objects: `aR`/`iR` (Rule), `aW`/`iW` (When), `aT`/`iT` (Then), `aD`/`iD` (Declare).

### 3.10 DSL Expansion Preview (`lua/drools/dsl.lua`)
- ✅ **Completed**: `:DroolsExpandDSL` expands `.dsl` domain mappings into raw DRL code in a split preview.

---

## 4. Open Backlog for Future Releases

1. **Java Cross-Language Jump (`gd` to `.java`)**:
   - Interop with `nvim-jdtls` to jump from DRL `import` or fact types directly to Java class source files.
2. **DAP Debugger Breakpoints (`nvim-dap`)**:
   - Setting breakpoints inside DRL `when` conditions and `then` action blocks, mapping KieSession execution back to `.drl` buffer lines.
3. **Tabular Decision Table Importer (`.csv` / `.xlsx`)**:
   - Converting tabular CSV matrix rules into DRL code blocks.
