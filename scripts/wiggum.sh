#!/usr/bin/env bash
# wiggum.sh — Ralph Wiggum improvement loop for minecraft-seed-finder
#
# Each iteration: fresh AI agent picks an improvement (performance, readability,
# or Zig purity), benchmarks before/after, runs tests, commits if pass, resets
# if fail. Fresh context every iteration — no accumulated confusion.
#
# Usage:
#   ./scripts/wiggum.sh [max_iterations]   (default: 5)
#
# Models are randomly chosen between claude-opus-4-6 and gpt-5.3-codex.
set -euo pipefail

MAX_ITER="${1:-5}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT_DIR/tmp/wiggum"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$LOG_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

MODELS=("anthropic/claude-opus-4-6" "openai-codex/gpt-5.3-codex")

pick_model() {
    echo "${MODELS[$((RANDOM % ${#MODELS[@]}))]}"
}

# Benchmark queries — a mix of query shapes so improvements to any code path show up.
# All deterministic (fixed seed range), single-threaded.
#   Q1: single rare biome (~6s, biome noise dominated)
#   Q2: 2 common biomes (~3s, multi-biome scan)
#   Q3: 2 structures only (~0.1s, structure path)
#   Q4: mixed biome+structure (~7s, constraint reordering)
BENCH_QUERIES=(
    "--start-seed 0 --max-seed 5000000 --count 5 --require-biome eroded_badlands:3@500"
    "--start-seed 0 --max-seed 5000000 --count 3 --require-biome cherry_grove:2@300 --require-biome meadow:3@400"
    "--start-seed 0 --max-seed 5000000 --count 3 --require-structure village:400 --require-structure outpost:800"
    "--start-seed 0 --max-seed 5000000 --count 3 --require-biome cherry_grove:2@300 --require-biome meadow:3@400 --require-structure village:400 --require-structure outpost:800"
)
BENCH_LABELS=("rare_biome" "multi_biome" "structure_only" "mixed")

echo "=== Wiggum Loop ==="
echo "  max iterations: $MAX_ITER"
echo "  run dir: $RUN_DIR"
echo "  models: ${MODELS[*]}"
echo ""

# Build once before starting
echo "Building seed-finder..."
(cd "$ROOT_DIR" && zig build -Doptimize=ReleaseFast)

iter=0
improved=0
failed=0

while [ "$iter" -lt "$MAX_ITER" ]; do
    iter=$((iter + 1))
    model="$(pick_model)"
    iter_log="$RUN_DIR/iter-${iter}.log"
    
    echo "--- Iteration $iter/$MAX_ITER (model: $model) ---"

    # Snapshot current state
    git_before="$(cd "$ROOT_DIR" && git rev-parse HEAD)"

    # The prompt — this is the entire context the agent gets each iteration.
    # It must be self-contained since each iteration is a fresh process.
    prompt="$(cat <<'PROMPT'
You are improving the minecraft-seed-finder Zig codebase. You have ONE iteration
to make ONE focused improvement. Pick the single highest-value change from:

  1. **Performance** — speed up the hot path (biome noise, structure checks,
     constraint evaluation, search loop). Profile first, measure after.
  2. **Readability** — simplify convoluted auto-translated C patterns in
     cubiomes_port.zig or improve the pure-Zig search code.
  3. **Zig purity** — replace remaining C-isms with idiomatic Zig (e.g.,
     sentinel pointers → slices, manual null checks → optionals, C-style
     loops → Zig iterators).

RULES:
- Read the recent git log (`git log --oneline -20`) to see what's been done.
  Don't repeat prior work.
- Read src/ files to understand the codebase before changing anything.
- Make ONE focused change. Don't boil the ocean.
- Do NOT touch test infrastructure, build.zig, scripts/, or bench/.
- Do NOT change any public API or CLI interface.

BENCHMARK (for timing, if your change targets performance):
Run these 4 queries before AND after. They cover different hot paths.
  # Q1: rare biome (~6s, biome noise dominated)
  time ./zig-out/bin/seed-finder --version 1.21.1 --edition bedrock \
    --start-seed 0 --max-seed 5000000 --count 5 \
    --require-biome "eroded_badlands:3@500"
  # Q2: multi-biome (~3s, multi-biome scan)
  time ./zig-out/bin/seed-finder --version 1.21.1 --edition bedrock \
    --start-seed 0 --max-seed 5000000 --count 3 \
    --require-biome "cherry_grove:2@300" --require-biome "meadow:3@400"
  # Q3: structure only (~0.1s, structure path)
  time ./zig-out/bin/seed-finder --version 1.21.1 --edition bedrock \
    --start-seed 0 --max-seed 5000000 --count 3 \
    --require-structure "village:400" --require-structure "outpost:800"
  # Q4: mixed biome+structure (~7s, constraint reordering)
  time ./zig-out/bin/seed-finder --version 1.21.1 --edition bedrock \
    --start-seed 0 --max-seed 5000000 --count 3 \
    --require-biome "cherry_grove:2@300" --require-biome "meadow:3@400" \
    --require-structure "village:400" --require-structure "outpost:800"

Biome noise dominates (~100ms/seed). Structures are cheap (~2ms/seed).
Report before/after times for whichever queries are relevant to your change.

WORKFLOW:
1. Explore: `git log --oneline -20`, read key source files, decide your strategy.
2. Write a brief plan (1-3 sentences) to stdout.
3. If targeting performance, run the benchmark command above and note the time.
4. Make the code changes.
5. Build: `zig build -Doptimize=ReleaseFast`
   - If build fails, fix it or `git checkout -- .` and output BAIL.
6. Test: `zig build test`
   - If tests fail, fix or `git checkout -- .` and output BAIL.
7. Quick equivalence: run `just equivalence-quick`
   - If it fails, fix or `git checkout -- .` and output BAIL.
8. If targeting performance, run the benchmark again and report before/after.
9. If all pass, commit with a descriptive message including any timing results:
   `git add -A && git commit -m "<what you did>"`
10. Output exactly one of these on its own line:
   - IMPROVED — you committed a meaningful change
   - BAIL — you couldn't find a valid improvement, rolled back
   - NO_IMPROVEMENT — you looked and there's nothing worthwhile left

Do NOT output IMPROVED unless you actually committed.
PROMPT
)"

    # Run the agent with fresh context
    (cd "$ROOT_DIR" && pi -p \
        --model "$model" \
        --thinking medium \
        --no-session \
        "$prompt" \
    ) 2>&1 | tee "$iter_log"

    # Check the outcome
    outcome="UNKNOWN"
    if grep -q "^IMPROVED$\|IMPROVED" "$iter_log"; then
        outcome="IMPROVED"
    elif grep -q "^NO_IMPROVEMENT$\|NO_IMPROVEMENT" "$iter_log"; then
        outcome="NO_IMPROVEMENT"
    elif grep -q "^BAIL$\|BAIL" "$iter_log"; then
        outcome="BAIL"
    fi

    git_after="$(cd "$ROOT_DIR" && git rev-parse HEAD)"

    # Safety net: if agent said IMPROVED but didn't actually commit, reset
    if [ "$outcome" = "IMPROVED" ] && [ "$git_before" = "$git_after" ]; then
        echo "  WARNING: Agent said IMPROVED but no commit found. Treating as BAIL."
        outcome="BAIL"
    fi

    # Safety net: if agent left dirty state without committing, reset
    if [ -n "$(cd "$ROOT_DIR" && git status --porcelain)" ]; then
        echo "  WARNING: Dirty working tree after iteration. Resetting."
        (cd "$ROOT_DIR" && git checkout -- . && git clean -fd)
        outcome="BAIL"
    fi

    case "$outcome" in
        IMPROVED)
            improved=$((improved + 1))
            echo "  ✓ Iteration $iter: IMPROVED ($(cd "$ROOT_DIR" && git log --oneline -1))"
            # Rebuild for next iteration's benchmark baseline
            (cd "$ROOT_DIR" && zig build -Doptimize=ReleaseFast)
            ;;
        NO_IMPROVEMENT)
            echo "  ○ Iteration $iter: NO_IMPROVEMENT — stopping loop."
            break
            ;;
        BAIL)
            failed=$((failed + 1))
            echo "  ✗ Iteration $iter: BAIL"
            ;;
        *)
            failed=$((failed + 1))
            echo "  ? Iteration $iter: UNKNOWN outcome — treating as BAIL"
            # Reset just in case
            (cd "$ROOT_DIR" && git checkout -- . && git clean -fd 2>/dev/null || true)
            ;;
    esac

    echo ""
done

echo "=== Wiggum Loop Complete ==="
echo "  Iterations: $iter"
echo "  Improved:   $improved"
echo "  Failed:     $failed"
echo "  Logs:       $RUN_DIR/"

# Show what changed
if [ "$improved" -gt 0 ]; then
    echo ""
    echo "Commits from this run:"
    (cd "$ROOT_DIR" && git log --oneline -"$improved")
fi
