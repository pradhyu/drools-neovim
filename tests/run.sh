#!/usr/bin/env bash
# tests/run.sh — regression tests for the Drools Lua linter.
#   tests/valid/*.drl   must produce 0 diagnostics
#   tests/invalid/*.drl must produce >= 1 diagnostic
# Usage: tests/run.sh            (run from the repo root)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
fail=0

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


if command -v tree-sitter >/dev/null; then
  echo "== Tree-sitter grammar =="
  cd "$ROOT/tree-sitter-drools" || exit 1
  for f in "$ROOT"/tests/valid/*.drl; do
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then echo "  ok   $f"; else
      echo "  FAIL $f"; tree-sitter parse -q "$f" 2>/dev/null | tail -1; fail=1; fi
  done
  for f in "$ROOT"/tests/invalid/*.drl; do
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then echo "  lenient $f (grammar accepts; linter must catch)"; else
      echo "  ok   $f"; fi
  done
fi

[ "$fail" -eq 0 ] && echo "ALL PASSED" || { echo "FAILURES"; exit 1; }
