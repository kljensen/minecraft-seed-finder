<img src="assets/logo.svg" width="120" alt="minecraft-seed-finder logo" />

# minecraft-seed-finder

[![CI](https://img.shields.io/github/actions/workflow/status/kljensen/minecraft-seed-finder/ci.yml?branch=main&label=CI)](https://github.com/kljensen/minecraft-seed-finder/actions/workflows/ci.yml)
[![Zig 0.14.0+](https://img.shields.io/badge/Zig-0.14.0%2B-F7A41D?logo=zig&logoColor=white)](https://ziglang.org/)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue)](https://unlicense.org/)
[![Minecraft: Bedrock + Java](https://img.shields.io/badge/Minecraft-Bedrock%20%2B%20Java-5C8B22)](https://minecraft.net)

A Minecraft seed finder written in Zig. Search for seeds by biome, structure,
or any combination using boolean expressions.

Built on [cubiomes](https://github.com/Cubitect/cubiomes) by Cubitect — an
excellent C library that reverse-engineers Minecraft's world generation.
The generation logic was initially auto-translated from cubiomes into Zig and
then incrementally rewritten: many core functions are now idiomatic Zig, while
some low-level noise routines remain close to the original C (where the
auto-translated code still produces better machine code). The search layer adds
targeted optimizations on top.

- **Bedrock + Java**, MC 1.18 – 1.21.1
- **Biome + structure search** with radius constraints, count thresholds, and `and`/`or`/`not` composition
- **Key optimizations** — constraint reordering, climate early-exit, and coarse-to-fine biome prescans — yield 10–21× on combined queries in ablation tests (see [Performance](#performance))
- **Multi-threaded** — near-linear scaling with `--threads auto`
- **Resumable** — checkpoint and resume long scans
- **Output**: `text`, `jsonl`, `csv`; pipe-friendly or write to file
- Single static binary, no runtime dependencies

## Quick start

Requires [Zig](https://ziglang.org/) 0.14.0+.

```sh
zig build -Doptimize=ReleaseFast
```

Find [flower forest](https://minecraft.wiki/w/Flower_Forest) +
[meadow](https://minecraft.wiki/w/Meadow) near spawn with
[jagged peaks](https://minecraft.wiki/w/Jagged_Peaks),
[lush caves](https://minecraft.wiki/w/Lush_Caves), and a
[deep dark](https://minecraft.wiki/w/Deep_Dark) nearby, plus a
[village](https://minecraft.wiki/w/Village):

```sh
zig build run -Doptimize=ReleaseFast -- \
  --random --count 3 --threads auto \
  --require-biome "flower_forest:2@50" \
  --require-biome "meadow:2@80" \
  --require-biome "jagged_peaks:3@350" \
  --require-biome "lush_caves:1@800" \
  --require-biome "deep_dark:1@800" \
  --require-terrain "height_range:..5@50" \
  --require-structure "village:400"
```

## Example seeds

All examples use Bedrock edition (the default), MC 1.21.1, random seed sampling.
Results vary each run — these are real seeds from one run of each command.

**[Cherry grove](https://minecraft.wiki/w/Cherry_Grove) with a [village](https://minecraft.wiki/w/Village) and [outpost](https://minecraft.wiki/w/Pillager_Outpost) nearby** (~4 s single-thread)

```sh
seed-finder --version 1.21.1 --random --count 5 \
  --require-biome "cherry_grove:1@300" \
  --require-structure "village:400" \
  --require-structure "outpost:800"
```

```
seed=886 7242 5207 7709 2323  spawn=(0,0)     cherry_grove@222  village@283  outpost@678
seed=-317 9391 2252 5228 0958 spawn=(16,0)    cherry_grove@159  village@305  outpost@482
seed=-910 4215 7108 1848 7959 spawn=(-16,16)  cherry_grove@64   village@329  outpost@575
```

**[Eroded badlands](https://minecraft.wiki/w/Badlands#Eroded_Badlands) with a [desert pyramid](https://minecraft.wiki/w/Desert_Pyramid) and [village](https://minecraft.wiki/w/Village)** (~1 s single-thread)

```sh
seed-finder --version 1.21.1 --random --count 5 \
  --require-biome "eroded_badlands:1@400" \
  --require-structure "desert_pyramid:600" \
  --require-structure "village:400"
```

```
seed=330 6219 5212 5272 4352  spawn=(0,0)    eroded_badlands@4    village@192  desert_pyramid@329
seed=103 3528 9898 9757 7741  spawn=(-48,0)  eroded_badlands@179  village@204  desert_pyramid@125
seed=502 1688 5111 1532 0908  spawn=(0,0)    eroded_badlands@46   village@283  desert_pyramid@402
```

**[Jagged peaks](https://minecraft.wiki/w/Jagged_Peaks) with a [village](https://minecraft.wiki/w/Village) and [outpost](https://minecraft.wiki/w/Pillager_Outpost)** (~10 s with `--threads auto`)

```sh
seed-finder --version 1.21.1 --random --count 5 --threads auto \
  --require-biome "jagged_peaks:1@300" \
  --require-structure "village:400" \
  --require-structure "outpost:600"
```

```
seed=390 9604 4403 0516 8472  spawn=(0,0)   jagged_peaks@78   village@254  outpost@264
seed=-807 5115 1774 6899 7460 spawn=(0,0)   jagged_peaks@14   village@354  outpost@468
seed=409 8352 6067 1576 6184  spawn=(0,0)   jagged_peaks@165  village@354  outpost@319
```

## Usage

```
seed-finder --count <N> [options]
```

### Constraints

```
--require-biome <name:radius>         at least 1 chunk of biome within radius
--require-biome <name:count@radius>   at least count chunks within radius
--require-structure <name:radius>     structure within radius blocks
--where <expr>                        boolean filter (see below)
```

Constraints are numbered in the order they appear: biomes get `b1`, `b2`, ...
and structures get `s1`, `s2`, ... (or `c1`, `c2`, ... in overall order).
Use `--where` to combine them:

```sh
--require-biome "plains:96" \
--require-structure "village:400" \
--require-structure "mansion:1200" \
--where "b1 and (s1 or s2)"
```

Operators: `and`, `or`, `not` (aliases `&&`, `||`, `!`). Parentheses for grouping.

### Search options

```
--edition <java|bedrock>             Game edition (default: bedrock)
--version <1.18|1.19|1.20|1.21.1>   Minecraft version (default: 1.21.1)
--start-seed <u64>                   first seed to test (default: 0)
--max-seed <u64>                     stop after this seed
--anchor <x:z>                       evaluate around a fixed location
--random                             sample random seeds instead of scanning
--random-samples <N>                 number of random samples
--ranked                             keep top results by score
--top-k <N>                          how many to keep in ranked mode
--threads <N|auto>                   parallel workers (default: 0 = single-threaded)
```

### Output

```
--format <text|jsonl|csv>            output format (default: text)
--output <path>                      write results to file
--progress-every <N>                 print progress every N seeds
```

### Checkpointing

Long scans can be interrupted and resumed:

```sh
# Start a scan with checkpointing
zig build run -- --count 10 --max-seed 50000000 \
  --require-structure "village:500" \
  --checkpoint /tmp/scan.ckpt --checkpoint-every 200000

# Resume later
zig build run -- --count 10 --max-seed 50000000 \
  --require-structure "village:500" \
  --checkpoint /tmp/scan.ckpt --resume
```

### Other

```
--level-dat <path>                   import seed from a world save
--list-biomes                        print accepted biome names
--list-structures                    print accepted structure names
--help                               show help
```

## Supported structures

[`ancient_city`](https://minecraft.wiki/w/Ancient_City) ·
[`desert_pyramid`](https://minecraft.wiki/w/Desert_Pyramid) ·
[`igloo`](https://minecraft.wiki/w/Igloo) ·
[`jungle_pyramid`](https://minecraft.wiki/w/Jungle_Pyramid) ·
[`mansion`](https://minecraft.wiki/w/Woodland_Mansion) ·
[`monument`](https://minecraft.wiki/w/Ocean_Monument) ·
[`ocean_ruin`](https://minecraft.wiki/w/Ocean_Ruins) ·
[`outpost`](https://minecraft.wiki/w/Pillager_Outpost) ·
[`ruined_portal`](https://minecraft.wiki/w/Ruined_Portal) ·
[`shipwreck`](https://minecraft.wiki/w/Shipwreck) ·
[`swamp_hut`](https://minecraft.wiki/w/Swamp_Hut) ·
[`treasure`](https://minecraft.wiki/w/Buried_Treasure) ·
[`village`](https://minecraft.wiki/w/Village)

All [biomes](https://minecraft.wiki/w/Biome) from MC 1.18–1.21.1 are supported.
Run `--list-biomes` to see the full list.

## Testing

```sh
zig build test                 # unit tests
just equivalence               # golden files, format consistency, fuzz
just fuzz                      # differential fuzz against C reference
just conformance               # full CLI conformance (requires C sources)
```

## Performance

### Ablation: how much do the optimizations matter?

To measure the combined effect of the algorithmic choices —
constraint reordering, climate early-exit, and coarse-to-fine biome prescans —
`bench/c_reference.c` implements the exact same search *without* them. Same
circular biome grid, same impossible-fail short-circuit, same structure region
math, but it calls `getBiomeAt()` unconditionally (all 6 climate parameters
every time) and always checks biomes before structures (naive ordering).

This is an ablation test, not a comparison against another tool.
Reproduce with `sh scripts/bench_vs_c_ref.sh`.

The numbers below were measured at one point during development (Apple M1 Max,
anchored at (0,0), single-threaded, Java edition, MC 1.21.1). The optimized
side has gotten faster since these were recorded, so the actual gap today is
likely larger. Both versions find identical seeds.

| Query | Without opts | With opts | Difference |
|-------|-------------|-----------|------------|
| `cherry_grove:1@300` + `village:400` + `outpost:800` (first 5) |  19.7s |  1.9s | 10× |
| `ice_spikes:1@500`   + `village:400` + `outpost:600` (first 5) | 102.5s |  4.8s | 21× |

Why so large? The effects multiply:

**Constraint reordering** evaluates cheap structure constraints first. Both
queries require two structures, which together reject ~99% of seeds before any
biome scan runs. The unoptimized version pays the full biome scan cost for
every seed.

**Climate early-exit** samples climate parameters one at a time per biome grid
point, stopping as soon as one parameter rules out the target biome. The
unoptimized version evaluates all 6 parameters unconditionally.

**Coarse-to-fine biome prescans** check a sparse grid first (stride-8) before
filling in the full resolution, skipping most of the fine-grained sampling for
seeds that clearly pass or fail.

For structure-only queries there is no meaningful difference — both use the
same region coordinate math and viability checks.

### Multi-threading

Use `--threads auto` (or `--threads N`) for near-linear scaling:

| Threads | Speedup |
|---------|---------|
| 1 (ST)  | 1.0x    |
| 2       | 1.9x    |
| 4       | 3.7x    |
| 8       | 5.8x    |

Each thread gets its own Generator and evaluation state — seeds are
embarrassingly parallel.

### Optimization history

The port was iteratively profiled and optimized. Speedups below are
before/after measurements from individual commits on specific benchmark
queries. They don't compound straightforwardly — later wins sometimes overlap
with earlier ones.

Speedups were measured on four internal benchmark queries: a single rare
biome, a multi-biome scan, a structure-only query, and a mixed
biome+structure query.

**Algorithmic changes:**

| Speedup | Optimization |
|---------|-------------|
| ~1.3× | Climate parameter early-exit — skip remaining noise calls when earlier parameters already rule out the target biome |
| 1.56× | Defer `getSpawn` for anchor queries — spawn was 36% of per-seed cost and wasted on seeds that fail constraints |
| 2.7× | Two-phase coarse-then-fine biome scan — stride-4 prescan, then fill only when the coarse pass is inconclusive (rare biome: 6.16s→2.28s) |
| 2.1× | Three-phase coarse prescan — stride-8, stride-4, then full (rare biome: 2.42s→1.14s) |
| 4.1× | Coarse prescan for combined biome threshold queries (multi-biome: 3.20s→0.79s) |
| 1.6× | Stride-8 coarse prescan for single-biome queries (rare biome: 1.35s→0.84s) |

**Smaller wins (1–6%):**

| Speedup | Optimization |
|---------|-------------|
| 1.06× | Cached sequential multi-biome scan — share noise cache across biome constraints |
| 1.04× | Rewrite `get_resulting_node`/`get_np_dist` biome tree walk as idiomatic Zig |
| 1.04× | Structure eval: region sorting by distance + constraint cost ordering |
| ~1% | Single-sample combined biome cache via union bounds (multi-biome: 0.84s→0.78s) |
| ~1% | Early-exit on humidity feasibility in fast biome path |

### What didn't work

| Result | Attempt |
|--------|---------|
| −1.2% | Rewriting `samplePerlin` as clean Zig — the auto-translated C code generates better machine code |
| −8.7% | Union climate bounds single-pass — merging per-biome bounds makes them too wide, defeating early-exit |
| 0% | SIMD vectorization — not on the hot path (only used in shadow probes) |
| 0% | Cached structure config fast-path — already fast enough |

## How it works

The core biome and structure generation logic comes from
[cubiomes](https://github.com/Cubitect/cubiomes) by Cubitect, a C library that
reimplements Minecraft's world generation. Cubiomes is the foundation — without
it this project would not exist.

The generation code was initially auto-translated from cubiomes C into Zig.
Since then, many core functions (`climateToBiome`, `sampleBiomeNoise`,
`sampleSimplex2D`, `biomeExists`, RNG/noise initialization, spline evaluation,
and others) have been rewritten as idiomatic Zig. Some hot inner loops like
`samplePerlin` remain close to the original C translation where it produces
better machine code. The generation core lives in `src/cubiomes_port.zig`
(~15K lines) plus ~47K lines of extracted biome tree lookup tables in
`src/btree_data.zig`.

On top of the generation layer, the search evaluator (`src/search_eval.zig`)
adds constraint reordering, climate early-exit, and coarse-to-fine biome
prescans. The search loop iterates over seeds, evaluates structure placement
via region coordinate math, and samples biome noise to check constraints. A
boolean expression engine lets you compose constraints with `and`/`or`/`not`
logic.

## License

The seed finder code is released under the [Unlicense](https://unlicense.org/)
(public domain).

The vendored cubiomes library (`lib/cubiomes/`) is under the
[MIT License](lib/cubiomes/LICENSE), copyright 2020 Cubitect.
