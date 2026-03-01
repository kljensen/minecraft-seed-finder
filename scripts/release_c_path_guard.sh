#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Checking for C binding imports in production files..."
violations=$(rg -n '^const c = @import\("c_bindings\.zig"\);' src/main.zig src/bedrock.zig || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: production files still import c_bindings"
  exit 1
fi

echo "PASS: no c_bindings imports in production files"
