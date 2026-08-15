# TODO & Feature Roadmap for `drools.nvim`

This document tracks planned features, enhancements, and architectural ideas for future releases of `drools.nvim`.

---

## 🚀 Future Feature Backlog

### 1. 🌉 Java LSP Cross-Language Navigation (`gd` to Java)
- [ ] Implement interop with `nvim-jdtls` / Java LSP.
- [ ] Jump from DRL `import` statements and fact types (e.g. `Customer`) to `.java` class definitions.
- [ ] Support navigation to field getters/setters referenced in LHS pattern constraints.

---

### 2. 📊 Rule Agenda & Execution Order Visualizer (`:DroolsAgenda`)
- [ ] Build a floating tree or sidebar view displaying rules organized by `agenda-group` and `salience`.
- [ ] Add warning indicators for potential infinite loop rules (missing `no-loop` or `lock-on-active` when updating facts).

---

### 3. 🕸️ Fact-Rule Dependency Graph (`:DroolsGraph`)
- [ ] Parse facts inserted/modified in RHS (`then`) and match them against LHS (`when`) patterns across rules.
- [ ] Export or render rule dependency chains using Mermaid or Graphviz in Neovim.

---

### 4. 💡 Code Actions & Refactorings (`vim.lsp.buf.code_action`)
- [ ] **Quick Fixes**:
  - Auto-insert missing `end` keywords for unclosed `rule` or `declare` blocks.
  - Auto-add missing `package` and `import` declarations.
  - Toggle rule execution status (`enabled true` / `enabled false`).
- [ ] **Refactorings**:
  - Extract pattern constraints to bound variables (e.g. `Person(...)` $\rightarrow$ `$p : Person(...)`).
  - Convert inline Java RHS logic into MVEL dialect or external `function`.

---

### 5. 🎯 Tree-Sitter Textobjects & Structural Motions
- [ ] Define custom Tree-Sitter textobjects for Drools constructs:
  - `ar` / `ir`: Around / Inside **Rule** block
  - `aw` / `iw`: Around / Inside **When** clause (LHS)
  - `at` / `it`: Around / Inside **Then** clause (RHS)
  - `ad` / `id`: Around / Inside **Declare** block

---

### 6. 🧪 Live Rule Sandbox & REPL (`:DroolsRepl`)
- [ ] Provide an interactive scratchpad window to input sample JSON/YAML facts.
- [ ] Execute current `.drl` file against sample facts in a lightweight background Java runner.
- [ ] Display rule activation log and modified facts in real-time.

---

### 7. 📑 Decision Table (`.xlsx` / `.csv`) & DSL Integration
- [ ] Add `:DroolsExpandDSL` to expand DSL rules into raw DRL in a split preview window.
- [ ] Add `:DroolsConvertTable` to convert tabular CSV matrices into DRL rule blocks.

---

### 8. 🐛 DAP Breakpoint Integration
- [ ] Integrate with `nvim-dap` for setting breakpoints on DRL LHS pattern lines and RHS action lines.
- [ ] Map Java KieSession execution stackframes back to corresponding `.drl` buffer lines.
