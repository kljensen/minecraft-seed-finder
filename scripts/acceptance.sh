#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

PURE_ZIG=PASS
PARITY=PASS
PERF=PASS
BLOCKERS="none"

add_blocker() {
  msg="$1"
  if [ "$BLOCKERS" = "none" ]; then
    BLOCKERS="$msg"
  else
    BLOCKERS="$BLOCKERS; $msg"
  fi
}

# Pure-Zig guard: production paths should not import c_bindings.
# (Tests/harness may still use C.)
if rg -n '^const c = @import\("c_bindings\.zig"\);' src/main.zig src/bedrock.zig >/dev/null 2>&1; then
  PURE_ZIG=FAIL
  add_blocker "production path still imports c_bindings"
fi

# Parity guard: latest strict parity history must not contain mismatches
# and must have no non-zero strict-run return codes.
if [ -f tmp/perf/pure_zig_parity_50.jsonl ]; then
  latest_run_id=$(jq -r 'select(.run_id != null) | .run_id' tmp/perf/pure_zig_parity_50.jsonl | tail -n 1)
  if [ -z "$latest_run_id" ]; then
    PARITY=FAIL
    add_blocker "strict parity data missing run_id"
  else
    parity_rows=$(jq -s --arg rid "$latest_run_id" '
      [ .[] | select(.run_id == $rid) ] as $rows |
      {
        count: ($rows | length),
        compared: ($rows | map(.compared // 0) | add // 0),
        mismatch: ($rows | map(.mismatch // 0) | add // 0),
        nonzero_rc: ($rows | map(select((.rc // 0) != 0)) | length)
      }
    ' tmp/perf/pure_zig_parity_50.jsonl)
    row_count=$(printf '%s\n' "$parity_rows" | jq -r '.count')
    total_compared=$(printf '%s\n' "$parity_rows" | jq -r '.compared')
    total_mismatch=$(printf '%s\n' "$parity_rows" | jq -r '.mismatch')
    nonzero_rc=$(printf '%s\n' "$parity_rows" | jq -r '.nonzero_rc')
    if [ "$row_count" -eq 0 ] || [ "$total_compared" -eq 0 ] || [ "$total_mismatch" -ne 0 ] || [ "$nonzero_rc" -ne 0 ]; then
      PARITY=FAIL
      add_blocker "strict parity latest run invalid (run_id=$latest_run_id compared=$total_compared mismatch=$total_mismatch rc_nonzero=$nonzero_rc)"
    fi
  fi
else
  PARITY=FAIL
  add_blocker "missing tmp/perf/pure_zig_parity_50.jsonl"
fi

# Perf guard: require history file and at least one parallel mode sample.
if [ ! -f tmp/perf/history.jsonl ]; then
  PERF=FAIL
  add_blocker "missing tmp/perf/history.jsonl"
else
  parallel_count=$(jq -s 'map(select(.label=="parallel" or .label=="parallel_simd"))|length' tmp/perf/history.jsonl)
  if [ "$parallel_count" -lt 1 ]; then
    PERF=FAIL
    add_blocker "no parallel benchmark samples"
  fi
fi

if [ "$PURE_ZIG" = PASS ] && [ "$PARITY" = PASS ] && [ "$PERF" = PASS ]; then
  echo "LGTM: yes"
else
  echo "LGTM: no"
fi

echo "PURE_ZIG: $PURE_ZIG"
echo "PARITY: $PARITY"
echo "PERF: $PERF"
echo "BLOCKERS: $BLOCKERS"
