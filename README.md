# drools.nvim

A feature-complete Neovim plugin for **Drools Rule Language (`.drl`, `.dsl`)** providing syntax highlighting, tree-sitter queries, smart indentation, snippet templates, static syntax diagnostics, document symbol navigation, code formatting, test runner execution, and Language Server (LSP) integration.

---

## Features

- 🎨 **Syntax Highlighting**: High-precision Vim regex highlighting and Tree-sitter query support (`queries/drools/highlights.scm`).
- ⚡ **Filetype Detection**: Native filetype mapping for `.drl` and `.dsl` files.
- 🔍 **Static Syntax Linter**: Built-in diagnostic checker (`:DroolsLint`) for missing `package`, unclosed `rule` blocks, `when`/`then` structural errors, and unbalanced parentheses/braces.
- 🗺️ **Navigation & Outline**: Document symbol extraction (`:DroolsSymbols`) and jump-to-definition (`gd` / `:DroolsGotoDefinition`) for fact types (`declare`) and imports.
- 🧹 **Code Formatter**: In-buffer DRL auto-formatting (`:DroolsFormat`).
- 🧪 **Rule Test Runner**: Automated test execution via Maven or Gradle in an integrated terminal (`:DroolsTest`).
- 🔭 **Telescope Integration**: Pick rules and fact symbols using `:Telescope drools`.
- 🧠 **LSP Ready**: Configurable launcher for the Drools Language Server (`drools_ls`).
- 📐 **Smart Indentation**: Automatic block indentation for `rule`, `when`, `then`, `declare`, and `query`.
- 📝 **Snippets**: Pre-packaged VS Code snippets for `LuaSnip` / `nvim-cmp`.
- 🩺 **Health Check**: Native `:checkhealth drools` integration.

---

## Installation

### With [`lazy.nvim`](https://github.com/folke/lazy.nvim)

```lua
{
  "drools-neovim", -- or path to local repository
  ft = { "drools" },
  opts = {
    linter = {
      enable = true,
      on_save = true,
    },
    snippets = {
      enable = true,
    },
  },
}
```

### Manual Setup in `init.lua`

```lua
require("drools").setup({
  highlight = { enable = true },
  linter = { enable = true, on_save = true },
  lsp = { enable = false }, -- Set true if drools-lsp-server.jar is installed
  snippets = { enable = true },
})
```

---

## User Commands & Keymaps

| Command | Keymap | Description |
|---|---|---|
| `:DroolsLint` | `<leader>dl` | Run static syntax analysis on current Drools buffer |
| `:DroolsFormat` | `<leader>df` | Auto-format current Drools buffer |
| `:DroolsSymbols` | `<leader>ds` | Show rules, queries, and fact symbol outline |
| `:DroolsGotoDefinition` | `gd` | Jump to definition of fact type or import |
| `:DroolsTest` | `<leader>dt` | Run Maven/Gradle test suite for Drools rules |
| `:Telescope drools` | - | Interactively browse rules and symbols with Telescope |
| `:checkhealth drools` | - | Verify plugin setup, filetype, and dependencies |

---

## Specification & Documentation

Refer to [SPECIFICATION.md](SPECIFICATION.md) for full architectural details and design specifications.
