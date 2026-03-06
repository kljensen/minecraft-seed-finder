#!/bin/sh
# Equivalence tests: verify seed-finder produces correct, consistent results
# across a variety of query shapes. Uses golden output comparison and
# cross-format consistency checks.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

BIN="./zig-out/bin/seed-finder"
PASS=0
FAIL=0
TOTAL=0

run_case() {
    label="$1"
    shift
    expected="$1"
    shift
    TOTAL=$((TOTAL + 1))
    actual=$("$BIN" "$@" 2>&1) || true
    if [ "$actual" = "$expected" ]; then
        printf "  PASS: %s\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s\n" "$label"
        printf "    expected: %s\n" "$(echo "$expected" | head -1)"
        printf "    actual:   %s\n" "$(echo "$actual" | head -1)"
        FAIL=$((FAIL + 1))
    fi
}

check_golden() {
    label="$1"
    golden="$2"
    shift 2
    TOTAL=$((TOTAL + 1))
    tmp=$(mktemp)
    "$BIN" "$@" > "$tmp" 2>&1 || true
    if cmp -s "$tmp" "$golden"; then
        printf "  PASS: %s\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (golden mismatch)\n" "$label"
        diff "$golden" "$tmp" | head -5
        FAIL=$((FAIL + 1))
    fi
    rm -f "$tmp"
}

# Consistency check: same query in text/jsonl/csv should find same seeds
check_format_consistency() {
    label="$1"
    shift
    TOTAL=$((TOTAL + 1))
    seeds_text=$("$BIN" "$@" --format text 2>&1 | grep '^seed=' | sed 's/seed=\([0-9 ]*\) .*/\1/' | tr -d ' ' | sort -n)
    seeds_jsonl=$("$BIN" "$@" --format jsonl 2>&1 | grep '"seed"' | sed 's/.*"seed":\([0-9]*\).*/\1/' | sort -n)
    seeds_csv=$("$BIN" "$@" --format csv 2>&1 | tail -n +2 | grep -v '^summary' | cut -d, -f1 | sort -n)
    if [ "$seeds_text" = "$seeds_jsonl" ] && [ "$seeds_text" = "$seeds_csv" ]; then
        printf "  PASS: %s (format consistency)\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (formats disagree on seeds)\n" "$label"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Golden file checks ==="
check_golden "stream text (java)" tests/golden/search_stream_spawn_anchor.txt \
    --edition java --version 1.21.1 --start-seed 0 --max-seed 500 --count 8 --format text \
    --require-biome "plains:4@200" --require-structure "village:500" --where "b1 and s1"

check_golden "ranked jsonl (java)" tests/golden/search_ranked_jsonl.txt \
    --edition java --version 1.21.1 --start-seed 0 --max-seed 500 --count 8 --ranked --top-k 6 --format jsonl \
    --require-biome "plains:4@200" --require-structure "village:500" --where "b1 and s1"

check_golden "stream csv (java)" tests/golden/search_stream_spawn_anchor.csv \
    --edition java --version 1.21.1 --start-seed 0 --max-seed 500 --count 8 --format csv \
    --require-biome "plains:4@200" --require-structure "village:500" --where "b1 and s1"

echo ""
echo "=== Format consistency checks ==="
check_format_consistency "biome-only plains" \
    --version 1.21.1 --start-seed 0 --max-seed 200 --count 5 \
    --require-biome "plains:4@200"

check_format_consistency "structure-only village" \
    --version 1.21.1 --start-seed 0 --max-seed 50 --count 5 \
    --require-structure "village:500"

check_format_consistency "biome+structure anchored" \
    --version 1.21.1 --start-seed 0 --max-seed 200 --count 3 --anchor 0:0 \
    --require-biome "forest:3@200" --require-structure "village:600" --where "b1 and s1"

echo ""
echo "=== Diverse query shapes ==="

# Single biome, small radius
run_case "cherry_grove@100 seed 18" \
    "seed=18 spawn=(-80,144) anchor=(-80,144) score=1.456 matched=1/1 diagnostics=b1=ok(122)@54.4
summary: found=1 tested=19 start_seed=0 end_seed=17" \
    --version 1.21.1 --start-seed 0 --max-seed 19 --count 1 --format text \
    --require-biome "cherry_grove:1@100"

# OR expression
check_format_consistency "OR expression" \
    --version 1.21.1 --start-seed 0 --max-seed 100 --count 3 \
    --require-biome "jungle:2@300" --require-biome "desert:2@300" --where "b1 or b2"

# NOT expression
check_format_consistency "NOT expression" \
    --version 1.21.1 --start-seed 0 --max-seed 100 --count 3 \
    --require-biome "plains:10@200" --require-biome "desert:1@300" --where "b1 and not b2"

# Multiple structures
check_format_consistency "multi-structure" \
    --version 1.21.1 --start-seed 0 --max-seed 500 --count 2 \
    --require-structure "village:500" --require-structure "outpost:1000" --where "s1 and s2"

# High min_count biome
check_format_consistency "high count biome" \
    --version 1.21.1 --start-seed 0 --max-seed 50 --count 3 \
    --require-biome "plains:20@300"

# Anchored at offset
check_format_consistency "anchored offset" \
    --version 1.21.1 --start-seed 0 --max-seed 100 --count 3 --anchor 1000:1000 \
    --require-biome "forest:3@200"

# Ranked mode
check_format_consistency "ranked mode" \
    --version 1.21.1 --start-seed 0 --max-seed 200 --count 5 --ranked --top-k 3 \
    --require-biome "plains:4@200"

echo ""
echo "=== Fuzz: randomized seed ranges ==="
FUZZ_ROUNDS="${1:-5}"
round=1
while [ "$round" -le "$FUZZ_ROUNDS" ]; do
    start=$(($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % 100000))
    span=$((500 + $(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % 2000))
    max=$((start + span))
    TOTAL=$((TOTAL + 1))

    seeds_text=$("$BIN" --version 1.21.1 --start-seed "$start" --max-seed "$max" --count 5 \
        --format text --anchor 0:0 \
        --require-biome "plains:3@200" --require-structure "village:600" --where "b1 and s1" 2>&1 \
        | grep '^seed=' | sed 's/seed=\([0-9 ]*\) .*/\1/' | tr -d ' ' | sort -n)
    seeds_jsonl=$("$BIN" --version 1.21.1 --start-seed "$start" --max-seed "$max" --count 5 \
        --format jsonl --anchor 0:0 \
        --require-biome "plains:3@200" --require-structure "village:600" --where "b1 and s1" 2>&1 \
        | grep '"seed"' | sed 's/.*"seed":\([0-9]*\).*/\1/' | sort -n)

    if [ "$seeds_text" = "$seeds_jsonl" ]; then
        printf "  PASS: fuzz round %d (start=%d span=%d)\n" "$round" "$start" "$span"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: fuzz round %d (start=%d span=%d)\n" "$round" "$start" "$span"
        FAIL=$((FAIL + 1))
    fi
    round=$((round + 1))
done

echo ""
echo "=== Results ==="
echo "Passed: $PASS / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED: $FAIL"
    exit 1
else
    echo "All tests passed."
fi
