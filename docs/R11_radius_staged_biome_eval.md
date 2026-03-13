# R11: Radius-Aware Staged Biome Evaluation (REVERTED)

**Date:** 2026-03-03
**Result:** Neutral (~1% within noise). Reverted.
**Iterations:** 1

## Hypothesis

The R09 `combinedBiomeThreshold` cache forces all biome constraints to be
evaluated on the LARGEST radius grid. For a mixed-radius query like
`flower_forest:2@50` + `lush_caves:1@600`, the @50 biome (needing ~49 points)
scans all ~7069 points in the @600 grid. Disabling the cache and evaluating
biomes sequentially on their own per-radius grids (smallest first) should yield
~100x fewer biome point evaluations for the hard 12-constraint query.

## Changes (reverted)

1. Disabled `combinedBiomeThreshold` (early `return null`)
2. Sorted biome atoms by radius ascending before sequential evaluation
3. Let existing `evalConstraintAt` fallback handle per-biome grids with
   climate early-exit

## Benchmark Results (50K seeds, --threads 1)

| Query                          | Baseline | R11    | Delta   |
|--------------------------------|----------|--------|---------|
| Hard 12-constraint             | 229.9s   | 227.0s | -1.3%   |
| Biome-only mixed-radius (7 biomes) | 187.5s   | 185.2s | -1.2%   |
| Same-radius @600 (3K seeds)    | 524.7s   | 517.2s | -1.4%   |

All deltas within run-to-run noise.

## Why It Didn't Work

The hypothesis had three flaws:

1. **Hard query is structure-dominated.** Adaptive reordering puts structures
   first, which reject ~97% of seeds before biomes are evaluated. Biome eval
   is <5% of total time, so even a 100x biome speedup yields <5% overall.

2. **Climate early-exit makes extra points nearly free.** The cache path
   iterates 7069 points for a @50 biome, but `fastBiomeIdWithFeasibility`
   rejects most points with just a few float comparisons (checking climate
   parameter bounds). The cost difference between iterating 49 vs 7069 points
   is tiny when 99%+ of the extra points bail after ~3 multiplies.

3. **Cache helps surviving seeds.** The ~3% of seeds that pass the first biome
   benefit from cached biome IDs when evaluating subsequent biomes. Removing
   the cache forces recomputation for those seeds, roughly canceling savings.

## Key Lesson

When an early-exit mechanism (climate bounds) already makes per-point cost
near-zero for non-matching points, reducing the number of points iterated
doesn't help much. The cache's value isn't in the iteration count -- it's in
avoiding redundant noise computation for seeds that survive multiple biome
checks. Point count only matters when per-point cost is non-trivial.
