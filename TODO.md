# TODO & Feature Roadmap for `drools.nvim`

This document tracks completed features, active capabilities, and open roadmap items for `drools.nvim`.

---

## ✅ Completed Features

- [x] **Comprehensive DRL Syntax Highlighting**: Native syntax highlighting (`syntax/drools.vim`) covering full Drools 8 syntax without external C/node dependencies.
- [x] **Real-Time Interactive Compiler Linter**: 2-phase Tokenizer + Recursive Descent Parser running live on `TextChanged`/`TextChangedI` with 100ms debouncing (`lua/drools/linter.lua`).
- [x] **Context-Aware Auto-Completion (`omnifunc`)**: Completion provider for DRL keywords, rule attributes, fact types, bound variables (`$var`), and RHS actions (`lua/drools/completion.lua`).
- [x] **Specification Hover & Lookup**: Floating docs lookup (`:DroolsHover`, `:DroolsSpec <kw>`) with 30+ embedded specification docs (`resources/drools_spec_docs.json`).
- [x] **Rule Agenda Priority Inspector**: Ranks rules by `salience` and `agenda-group` while warning about infinite loop risks (`:DroolsAgenda` / `<leader>da`).
- [x] **Quick-Fix Code Actions**: One-click menu to insert missing `end`, `no-loop true`, `package` headers, and toggle `enabled` state (`:DroolsCodeAction` / `<leader>ca`).
- [x] **Structural Text-Objects**: Uppercase text-objects `aR`/`iR` (Rule), `aW`/`iW` (When), `aT`/`iT` (Then), `aD`/`iD` (Declare).
- [x] **DSL Expansion Preview**: Expands `.dsl` domain mappings into raw DRL code in a split preview (`:DroolsExpandDSL`).
- [x] **Symbol Outline & Definition Jump**: Document symbol list (`:DroolsSymbols` / `<leader>ds`) and jump to definition (`gd` / `:DroolsGotoDefinition`).
- [x] **Maven/Gradle Test Runner**: Automated test execution directly inside Neovim split terminal (`:DroolsTest` / `<leader>dt`).
- [x] **Drools LSP Integration**: Configurable launcher for `drools-lsp-server.jar` with path expansion and automatic Maven/Gradle classpath indexing.

---

## 🚀 Open Future Backlog

### 1. 🌉 Java Cross-Language Jump (`gd` to `.java`)
- [ ] Implement interop with `nvim-jdtls` / Java LSP.
- [ ] Jump from DRL `import` statements and fact types (e.g. `Customer`) directly to `.java` class definitions.
- [ ] Support navigation to field getters/setters referenced in LHS pattern constraints.

### 2. 🐛 DAP Breakpoint Integration
- [ ] Integrate with `nvim-dap` for setting breakpoints on DRL LHS pattern lines and RHS action lines.
- [ ] Map Java KieSession execution stackframes back to corresponding `.drl` buffer lines.

### 3. 📑 Tabular Decision Table Importer (`.csv` / `.xlsx`)
- [ ] Add `:DroolsConvertTable` to convert tabular CSV matrices into DRL rule blocks.

### 4. 🧪 Live Rule Sandbox & REPL (`:DroolsRepl`)
- [ ] Interactive scratchpad window to input sample JSON/YAML facts and evaluate rule matches live.
