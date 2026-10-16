# drools.nvim

A feature-complete Neovim plugin for **Drools Rule Language (`.drl`, `.dsl`)** providing Tree-sitter primary syntax highlighting, smart indentation, snippet templates, AST static syntax diagnostics, document symbol navigation, code formatting, test runner execution, and Language Server (LSP) integration.

---

## Features

- 🌳 **Tree-Sitter Primary Syntax Engine**: Bundled formal Tree-sitter grammar (`tree-sitter-drools/`) and queries (`queries/drools/`) auto-compiled on opening Drools files, with manual rebuild via `:DroolsTSBuild`.
- 🎨 **Syntax Highlighting**: Full Drools 8 syntax highlighting (Rule Units, OOPath, CEP temporal operators, accumulate/groupby, multiline Java RHS) with fallback to native Vim regex.
- ⚡ **Filetype Detection**: Native filetype mapping for `.drl` and `.dsl` files.
- 🔍 **Real-Time AST Syntax Linter**: Built-in diagnostic checker (`:DroolsLint`) — a pure-Lua recursive-descent parser of the Drools DRL grammar that flags missing `package`, unclosed `rule` blocks, `when`/`then` order, and unbalanced parentheses/braces.
- 🗺️ **Navigation & Outline**: Document symbol extraction (`:DroolsSymbols`) and jump-to-definition (`gd` / `:DroolsGotoDefinition`) for fact types (`declare`) and imports.
- 🧹 **Code Formatter**: In-buffer DRL auto-formatting (`:DroolsFormat`).
- 🧪 **Rule Test Runner**: Automated test execution via Maven or Gradle in an integrated terminal (`:DroolsTest`).
- 🔭 **Telescope Integration**: Pick rules and fact symbols using `:Telescope drools`.
- 🧠 **LSP Ready**: Configurable launcher for the Drools Language Server (`drools_ls`) with path expansion.
- 💡 **Context-Aware Auto-Completion**: Native `omnifunc` (`<C-x><C-o>` / `nvim-cmp`) providing completion for DRL keywords, rule attributes, fact types, bound variables (`$var`), CEP temporal operators, and RHS actions.
- 📐 **Smart Indentation**: Automatic block indentation for `rule`, `when`, `then`, `declare`, and `query`.
- 📝 **Snippets**: Pre-packaged VS Code snippets for `LuaSnip` / `nvim-cmp`.
- 🩺 **Health Check**: Native `:checkhealth drools` integration.

---

## Installation

### With [`lazy.nvim`](https://github.com/folke/lazy.nvim)

```lua
{
  "pradhyu/drools-neovim",
  ft = { "drools", "dsl" },
  opts = {
    treesitter = {
      enable = true,
      prefer_treesitter_folding = true,
    },
    highlight = {
      enable = true,
    },
    linter = {
      enable = true,
      mode = "insert_leave",
    },
    snippets = {
      enable = true,
    },
    lsp = {
      enable = false, -- Set true to enable Drools Language Server
      cmd = { "java", "-jar", "~/.local/share/drools/drools-lsp-server.jar" },
    },
  },
}
```

### Manual Setup in `init.lua`

```lua
require("drools").setup({
  treesitter = { enable = true, prefer_treesitter_folding = true },
  highlight = { enable = true },
  linter = { enable = true, mode = "insert_leave" },
  lsp = { enable = false }, -- Set true if drools-lsp-server.jar is installed
  snippets = { enable = true },
})
```

---

## 🧠 Drools Language Server (LSP) & Custom Data Models

`drools.nvim` integrates seamlessly with the official **Apache KIE / Red Hat Drools Language Server (`drools-lsp-server.jar`)**.

### How Custom Data Models & Services Are Resolved

You **do not** need to build a custom LSP for your project! The generic Drools LSP automatically resolves custom domain models, global services, and framework classes:

1. **Automatic Root & Classpath Resolution**:
   When opening `.drl` files in a project containing a `pom.xml` (Maven) or `build.gradle` (Gradle), `drools-lsp` automatically indexes your project's compiled classes (`target/classes` or `build/classes`) and dependencies in `~/.m2/repository` / Gradle cache.

2. **IntelliSense for Custom Classes**:
   Provides full autocomplete, signature help, and type diagnostics for custom domain classes (e.g. `import com.mycompany.model.Customer;`, `global OrderService orderService;`).

### Quick Setup

1. **Install Java (JDK 11 or 17+)**.
2. **Download `drools-lsp-server.jar`** to `~/.local/share/drools/drools-lsp-server.jar` (or use `jbang`).
3. **Enable LSP in `drools.nvim`**:

```lua
require("drools").setup({
  lsp = {
    enable = true,
    -- Option A: Pre-built JAR
    cmd = { "java", "-jar", "~/.local/share/drools/drools-lsp-server.jar" },
    
    -- Option B: Auto-run via jbang (Zero manual JAR download)
    -- cmd = { "jbang", "org.kie:drools-lsp-server:RELEASE" },
  },
})
```

> 💡 **Tip**: Run `mvn compile` or `./gradlew compileJava` once so your custom model `.class` files exist in `target/classes` for the LSP to index!

#### Custom Classpath (Non-Maven/Gradle Projects)
If using Ant, Bazel, or custom directory structures, pass custom classpaths directly:
```lua
lsp = {
  enable = true,
  cmd = {
    "java",
    "-cp", vim.fn.expand("~/.local/share/drools/drools-lsp-server.jar:target/classes:lib/*"),
    "org.kie.drools.lsp.ServerMain",
  },
}
```

---

## User Commands & Keymaps

| Command | Keymap | Description |
|---|---|---|
| `:DroolsHover` | `<C-LeftMouse>` / `K` / `<leader>dh` | Show specification docs or definition hover popup |
| `:DroolsSpec [keyword]` | - | Show official Drools specification popup for any keyword (with tab completion) |
| `:DroolsGotoDefinition` | `gd` | Jump to definition of fact type, variable binding, or import |
| `:DroolsAgenda` | `<leader>da` | Inspect rule execution priority agenda and detect infinite loop risks |
| `:DroolsCodeAction` | `<leader>ca` | Show quick-fix code actions menu (auto-add end, no-loop, package, etc.) |
| `:DroolsExpandDSL` | - | Expand `.dsl` domain mappings into raw DRL in a split preview |
| `:DroolsLint` | `<leader>dl` | Run static syntax analysis on current Drools buffer |
| `:DroolsLintMode [mode]` | - | Set linter mode: `live` (Insert mode), `insert_leave` (on exit Insert), `on_save` (on save) |
| `:DroolsFoldRule` | `<leader>zR` | Collapse current rule block (`rule "Name"` to `end`) |
| `:DroolsFoldWhen` | `<leader>zW` | Collapse `when` condition block (`when` to `then`) |
| `:DroolsFoldThen` | `<leader>zT` | Collapse `then` action block (`then` to `end`) |
| `:DroolsFoldAllRules` | `<leader>zA` | Collapse ALL rules in buffer into 1-line headers |
| `:DroolsFoldAllWhen` | - | Collapse ALL `when` condition blocks across buffer |
| `:DroolsFoldAllThen` | - | Collapse ALL `then` action blocks across buffer |
| `:DroolsFoldExcept [query]` | `<leader>zF` | **Focus Mode**: Fold all rules EXCEPT those matching search query |
| `:DroolsUnfoldAll` | - | Unfold all collapsed blocks in buffer (`zR`) |
| `:DroolsFormat` | `<leader>df` | Auto-format current Drools buffer |
| `:DroolsSymbols` | `<leader>ds` | Show rules, queries, and fact symbol outline |
| `:DroolsTest` | `<leader>dt` | Run Maven/Gradle test suite for Drools rules |
| `:Telescope drools` | - | Interactively browse rules and symbols with Telescope |
| `:checkhealth drools` | - | Verify plugin setup, filetype, and dependencies |

### Structural Text-Objects & Motions

| Text-Object | Target | Example Usage |
|---|---|---|
| `aR` / `iR` | Around / Inside **Rule** block | `vaR` (select rule), `diR` (delete inside rule) |
| `aW` / `iW` | Around / Inside **When** clause | `viW` (select inside when), `daW` (delete when clause) |
| `aT` / `iT` | Around / Inside **Then** clause | `viT` (select inside then), `daT` (delete then clause) |
| `aD` / `iD` | Around / Inside **Declare** block | `vaD` (select declare block) |

---

## Specification & Roadmap

- Refer to [SPECIFICATION.md](SPECIFICATION.md) for architectural details and specifications.
- Refer to [TODO.md](TODO.md) for the upcoming feature backlog and roadmap.
