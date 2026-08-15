# drools.nvim

A feature-complete Neovim plugin for **Drools Rule Language (`.drl`, `.dsl`)** providing Tree-sitter primary syntax highlighting, formal ANTLR4-derived grammar, smart indentation, snippet templates, AST static syntax diagnostics, document symbol navigation, code formatting, test runner execution, and Language Server (LSP) integration.

---

## Features

- 🌳 **Tree-Sitter Primary Syntax Engine**: Formal Tree-sitter grammar ([`tree-sitter-drools/grammar.js`](tree-sitter-drools/grammar.js)) derived from official Apache KIE Drools ANTLR 4 parser specifications with capture queries ([`queries/drools/highlights.scm`](queries/drools/highlights.scm)).
- 🎨 **Vim Regex Fallback**: High-precision Vim regex highlighting ([`syntax/drools.vim`](syntax/drools.vim)) for environments without a compiled Tree-sitter parser.
- ⚡ **Filetype Detection**: Native filetype mapping for `.drl` and `.dsl` files.
- 🔍 **Real-Time AST Syntax Linter**: Built-in diagnostic checker (`:DroolsLint`) powered by Tree-sitter parser `(ERROR)` nodes and structural analysis for missing `package`, unclosed `rule` blocks, `when`/`then` order, and unbalanced parentheses/braces.
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
      use_ast_linter = true,
    },
    highlight = {
      enable = true,
      use_treesitter = true,
    },
    linter = {
      enable = true,
      on_save = true,
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
  treesitter = { enable = true },
  highlight = { enable = true, use_treesitter = true },
  linter = { enable = true, on_save = true },
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
| `:DroolsFormat` | `<leader>df` | Auto-format current Drools buffer |
| `:DroolsSymbols` | `<leader>ds` | Show rules, queries, and fact symbol outline |
| `:DroolsTest` | `<leader>dt` | Run Maven/Gradle test suite for Drools rules |
| `:Telescope drools` | - | Interactively browse rules and symbols with Telescope |
| `:checkhealth drools` | - | Verify plugin setup, filetype, and dependencies |

### Structural Text-Objects & Motions

| Text-Object | Target | Example Usage |
|---|---|---|
| `ar` / `ir` | Around / Inside **Rule** block | `var` (select rule), `dir` (delete inside rule) |
| `aw` / `iw` | Around / Inside **When** clause | `viw` (select inside when), `daw` (delete when clause) |
| `at` / `it` | Around / Inside **Then** clause | `vit` (select inside then), `dat` (delete then clause) |
| `ad` / `id` | Around / Inside **Declare** block | `vad` (select declare block) |

---

## Specification & Roadmap

- Refer to [SPECIFICATION.md](SPECIFICATION.md) for architectural details and specifications.
- Refer to [TODO.md](TODO.md) for the upcoming feature backlog and roadmap.
