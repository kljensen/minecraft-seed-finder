#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FILE="${1:-$ROOT_DIR/tmp/perf/native_shadow.jsonl}"

if [ ! -f "$FILE" ]; then
    echo "native shadow log not found: $FILE"
    exit 1
fi

jq -s '
  def nz(v): (if v == null then 0 else v end);
  def sum(f): map(f) | add;
  {
    runs: length,
    tested_total: sum(.tested),
    found_total: sum(.found),
    compared_total: sum(.compared),
    sign_mismatch_total: sum(.sign_mismatch),
    biome_proxy_compared_total: sum(nz(.biome_proxy_compared)),
    biome_proxy_mismatch_total: sum(nz(.biome_proxy_mismatch)),
    mean_abs_diff_weighted:
      (if (sum(.compared) == 0) then 0
       else (sum((.mean_abs_diff * .compared)) / sum(.compared))
       end),
    max_abs_diff_max: (map(.max_abs_diff) | max),
    sign_mismatch_rate:
      (if (sum(.compared) == 0) then 0
       else (sum(.sign_mismatch) / sum(.compared))
       end),
    biome_proxy_mismatch_rate:
      (if (sum(nz(.biome_proxy_compared)) == 0) then 0
       else (sum(nz(.biome_proxy_mismatch)) / sum(nz(.biome_proxy_compared)))
       end)
  }' "$FILE"
