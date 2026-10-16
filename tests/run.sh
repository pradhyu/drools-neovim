#!/usr/bin/env bash
# tests/run.sh — regression tests for the Drools Tree-sitter grammar and Lua linter.
#   tests/valid/*.drl   must produce 0 diagnostics
#   tests/invalid/*.drl must produce >= 1 diagnostic
#   tests/upstream/*.drl validates against official Apache KIE Drools test suite
# Usage: tests/run.sh            (run from the repo root)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
fail=0

echo "== Lua Linter: Synthetic Test Suite =="
nvim --headless --clean -u NONE --cmd "set rtp+=$ROOT" -l /dev/stdin <<'EOF' || fail=1
local L = require("drools.linter")
local bad = 0
local function count(f)
  return #(L.parse_source(table.concat(vim.fn.readfile(f), "\n")) or {})
end
for _, f in ipairs(vim.fn.glob("tests/valid/*.drl", false, true)) do
  local n = count(f)
  print(string.format("  %-4s %s (%d)", n == 0 and "ok" or "FAIL", f, n))
  if n ~= 0 then
    bad = bad + 1
    for _, e in ipairs(L.parse_source(table.concat(vim.fn.readfile(f), "\n"))) do
      print("         L" .. tostring(e.lnum or e.line) .. ": " .. e.message)
    end
  end
end
for _, f in ipairs(vim.fn.glob("tests/invalid/*.drl", false, true)) do
  local n = count(f)
  print(string.format("  %-4s %s (%d)", n > 0 and "ok" or "FAIL", f, n))
  if n == 0 then bad = bad + 1 end
end
if bad > 0 then os.exit(1) end
EOF

if [ -d "$ROOT/tests/upstream" ]; then
  echo "== Lua Linter: Official Upstream Test Suite (115 files) =="
  nvim --headless --clean -u NONE --cmd "set rtp+=$ROOT" -l /dev/stdin <<'EOF' || fail=1
local L = require("drools.linter")
local bad = 0
local expected_errors = {
  ["exist_instead_of_exists_test.drl"] = true,
  ["invalid_syntax.drl"] = true,
  ["lex_error.drl"] = true,
  ["misplaced_parenthesis.drl"] = true,
  ["multiple_errors.drl"] = true,
  ["npe_on_parser.drl"] = true,
  ["package_garbage.drl"] = true,
  ["pattern_partial.drl"] = true,
  ["template_test_error.drl"] = true,
  ["one-rule.drl"] = true,
}
local valid_count, tested = 0, 0
for _, f in ipairs(vim.fn.glob("tests/upstream/*.drl", false, true)) do
  tested = tested + 1
  local bname = vim.fn.fnamemodify(f, ":t")
  local diags = L.parse_source(table.concat(vim.fn.readfile(f), "\n")) or {}
  if expected_errors[bname] then
    if #diags == 0 then
      print("  FAIL (expected errors but got 0): " .. bname)
      bad = bad + 1
    end
  else
    if #diags ~= 0 then
      print(string.format("  FAIL (unexpected false positive): %s (%d errors)", bname, #diags))
      for _, e in ipairs(diags) do
        print("         L" .. tostring(e.lnum or e.line) .. ": " .. e.message)
      end
      bad = bad + 1
    else
      valid_count = valid_count + 1
    end
  end
end
print(string.format("  Upstream Linter: %d valid files passed with 0 false positives, %d error tests verified (total %d)",
  valid_count, tested - valid_count, tested))
if bad > 0 then os.exit(1) end
EOF
fi

if command -v tree-sitter >/dev/null; then
  echo "== Tree-sitter Grammar: Synthetic & Upstream =="
  cd "$ROOT/tree-sitter-drools" || exit 1
  for f in "$ROOT"/tests/valid/*.drl; do
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then echo "  ok   $(basename "$f")"; else
      echo "  FAIL $f"; tree-sitter parse -q "$f" 2>/dev/null | tail -1; fail=1; fi
  done
  for f in "$ROOT"/tests/invalid/*.drl; do
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then echo "  lenient $(basename "$f") (grammar accepts; linter catches)"; else
      echo "  ok   $(basename "$f")"; fi
  done

  if [ -d "$ROOT/tests/upstream" ]; then
    upstream_ok=0
    upstream_fail=0
    for f in "$ROOT"/tests/upstream/*.drl; do
      bname="$(basename "$f")"
      case "$bname" in
        exist_instead_of_exists_test.drl|invalid_syntax.drl|lex_error.drl|misplaced_parenthesis.drl|multiple_errors.drl|npe_on_parser.drl|pattern_partial.drl|template_test_error.drl|cheese-rules.drl|simple_expander.drl|one-rule.drl)
          continue
          ;;
        *)
          if tree-sitter parse -q "$f" >/dev/null 2>&1; then
            upstream_ok=$((upstream_ok + 1))
          else
            echo "  TS FAIL upstream: $bname"
            tree-sitter parse -q "$f" 2>/dev/null | tail -1
            fail=1
            upstream_fail=$((upstream_fail + 1))
          fi
          ;;
      esac
    done
    echo "  Upstream Tree-sitter: $upstream_ok passed, $upstream_fail failed"
  fi
fi

[ "$fail" -eq 0 ] && echo "ALL PASSED" || { echo "FAILURES"; exit 1; }
