# Specification for `drools.nvim` (Drools Neovim Plugin)

## 1. Overview & Objectives

`drools.nvim` is a Neovim plugin written in Lua to provide a rich development environment for **Drools Rule Language (`.drl`)** files.

### Key Features
- **Filetype Detection**: Automatically detect `.drl` files.
- **Syntax Highlighting**: Comprehensive highlighting for Drools keywords, rule constructs, LHS patterns, RHS Java/MVEL code, and attributes.
- **Syntax Checking & Diagnostics**: Integration with Drools Language Server (LSP) and external linters (`nvim-lint`, custom CLI validator).
- **Editing Enhancements**: Smart indentation, comment configuration, code folding, and snippet templates (LuaSnip / VS Code format).
- **Plugin Health Checks**: `checkhealth drools` module to verify syntax engine, LSP, and linter setup.

---

## 2. Directory Structure

```
drools-neovim/
├── ftdetect/
│   └── drools.lua            # Dynamic filetype registration
├── ftplugin/
│   └── drools.lua            # Buffer-local options, keymaps, comments
├── syntax/
│   └── drools.vim            # Legacy Vim regex syntax highlighting (fallback)
├── indent/
│   └── drools.lua            # Custom rule-based indentation logic
├── lua/
│   └── drools/
│       ├── init.lua          # Main plugin entrypoint & setup()
│       ├── config.lua        # Default options and user config merge
│       ├── lsp.lua           # Drools LSP server launcher & client config
│       ├── linter.lua        # Diagnostics provider (nvim-lint / built-in parser check)
│       ├── snippets.lua      # Snippet generator / LuaSnip loader
│       └── health.lua        # :checkhealth drools diagnostic check
├── queries/
│   └── drools/               # Tree-sitter queries (if tree-sitter grammar is present)
│       ├── highlights.scm
│       ├── folds.scm
│       └── indents.scm
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
- `foldmethod`, `foldexpr`: Configure rule-based folding (e.g., fold `rule ... end` blocks)

### 3.3 Syntax Highlighting Strategy
Dual-layer highlighting support:

#### Strategy A: Regex-based Vim Syntax (`syntax/drools.vim`)
- **Structure Keywords**: `package`, `import`, `global`, `function`, `query`, `declare`, `rule`, `when`, `then`, `end`.
- **Rule Attributes**: `salience`, `agenda-group`, `ruleflow-group`, `activation-group`, `lock-on-active`, `no-loop`, `auto-focus`, `enabled`, `dialect`, `duration`, `timer`, `calendars`.
- **LHS Conditional Operators**: `and`, `or`, `not`, `exists`, `forall`, `eval`, `from`, `over`, `entry-point`, `accumulate`, `collect`, `matches`, `contains`, `memberOf`, `soundslike`.
- **Variables**: Patterns starting with `$` (e.g., `$p : Person(...)`).
- **Data Types & Constants**: Java primitives, string literals (`"..."`, `'...'`), boolean (`true`, `false`), `null`.
- **RHS Block**: Sub-syntax embedding for Java/MVEL block inside `then ... end`.

#### Strategy B: Tree-Sitter Integration (`queries/drools/highlights.scm`)
Target node types for Drools grammar (or extended Java parser):
- Rule definition headers, pattern constraints, bound variables, RHS actions.

---

### 3.4 Syntax Checking & Diagnostics

#### A. LSP Integration (`lua/drools/lsp.lua`)
Integrate with the Drools Language Server (e.g., Red Hat KIE Drools LSP JAR or custom LS wrapper):
- Provide `drools.lsp.setup(user_config)` helper.
- Standard capabilities: completion, jump to definition (`import`, `declare`), diagnostics on parse error.

#### B. Lightweight Syntactic Validation (`lua/drools/linter.lua`)
Provide a lightweight validator when full LSP is unavailable:
1. **Unmatched Keywords Check**: Verify every `rule` has a matching `end`, every `when` has a `then`.
2. **Import & Package Check**: Ensure `package` statement is present at line 1.
3. **Integration with `nvim-lint`**: Expose a custom linter definition for `nvim-lint` or emit diagnostics directly via `vim.diagnostic.set(ns, bufnr, diagnostics)`.

---

### 3.5 Editing Features

#### A. Indentation (`indent/drools.lua`)
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

## 4. Lua API & Configuration Interface

### Default Options (`lua/drools/config.lua`)
```lua
local M = {}

M.defaults = {
  highlight = {
    enable = true,
    use_treesitter = false, -- Set true if custom parser installed
  },
  linter = {
    enable = true,
    on_save = true,
    lsp_fallback = true,
  },
  lsp = {
    cmd = { "java", "-jar", "drools-lsp-server.jar" },
    auto_start = true,
  },
  snippets = {
    enable = true,
  },
}

return M
```

### Main Entry Point (`lua/drools/init.lua`)
```lua
local config = require("drools.config")
local lsp = require("drools.lsp")
local linter = require("drools.linter")

local M = {}

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", config.defaults, user_opts or {})
  
  if M.options.lsp.auto_start then
    lsp.setup(M.options.lsp)
  end
  
  if M.options.linter.enable then
    linter.setup(M.options.linter)
  end
end

return M
```

---

## 5. Implementation Roadmap

| Phase | Target Deliverable | Description |
|---|---|---|
| **Phase 1** | Base Syntax & Filetype | Implement `ftdetect`, `ftplugin`, and legacy `syntax/drools.vim`. |
| **Phase 2** | Indentation & Snippets | Add `indent/drools.lua` and `snippets/drools.json` for LuaSnip/cmp. |
| **Phase 3** | Diagnostic Linter | Implement basic static syntax parser in `lua/drools/linter.lua` via `vim.diagnostic`. |
| **Phase 4** | LSP Client Setup | Build `lua/drools/lsp.lua` for Drools Language Server integration. |
| **Phase 5** | Health Check & Polish | Implement `:checkhealth drools` in `lua/drools/health.lua` and documentation. |
