# Minecraft Seed Finder

A fast Minecraft Java Edition seed finder written in Zig. Searches seeds by biome and
structure constraints using a pure-Zig port of
[cubiomes](https://github.com/Cubitect/cubiomes).

Find seeds with specific biomes near each other, structures within walking
distance, or complex combinations of both — then rank them by how well they
match.

## Quick start

Requires [Zig](https://ziglang.org/) 0.14.0+.

```sh
zig build -Doptimize=ReleaseFast
```

Find a flat valley below snowy peaks — level terrain at spawn, jagged peaks
with exposed coal towering nearby, lush caves and a deep dark underneath,
a village within walking distance:

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

ancient_city, desert_pyramid, igloo, jungle_pyramid, mansion, monument,
ocean_ruin, outpost, ruined_portal, shipwreck, swamp_hut, treasure, village

## Testing

```sh
zig build test                 # unit tests
just equivalence               # golden files, format consistency, fuzz
just fuzz                      # differential fuzz against C reference
just conformance               # full CLI conformance (requires C sources)
```

## Performance

### vs cubiomes C

Biome scanning is the expensive part of seed finding — each point requires
sampling 7 Perlin noise octaves across 6 climate dimensions. The seed-finder
optimizes this by checking climate parameters one at a time and skipping
remaining noise calls when earlier parameters already rule out the target biome.

Benchmarks scan 500 seeds starting from 0, anchored at the origin, single-threaded,
MC 1.21.1 on Apple M4. Both tools find identical matches.

| Query | cubiomes C | seed-finder | Speedup |
|-------|-----------|-------------|---------|
| `cherry_grove:1@300` | 28.7s | 21.0s | **1.37x** |
| `flower_forest:5@500` + `windswept_hills:5@500` | 78.6s | 61.1s | **1.29x** |

The advantage comes from climate early-exit: rare biomes like cherry grove have
narrow climate ranges, so most map points are rejected after sampling just 1-2
of the 6 noise parameters instead of all 7. The benefit scales with search
radius (more points to reject) and biome rarity.

Structure-only queries use the same algorithm as cubiomes (region coordinate
math + viability check) with no significant speed difference.

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

The Zig port was iteratively profiled and optimized over 10 rounds. Key wins
(measured as internal before/after on a hard biome+structure query):

| Speedup | Optimization |
|---------|-------------|
| ~1.3x | Climate parameter early-exit — skip remaining noise calls when earlier parameters already rule out the target biome |
| 1.56x | Defer `getSpawn` for anchor queries — spawn was 36% of per-seed cost and wasted on seeds that fail constraints |
| 1.06x | Cached sequential multi-biome scan — share noise cache across biome constraints |
| 1.04x | Rewrite `get_resulting_node`/`get_np_dist` biome tree walk as clean idiomatic Zig |
| 1.04x | Structure eval: region sorting by distance + constraint cost ordering |

### What didn't work

| Result | Attempt |
|--------|---------|
| -1.2% | Rewriting `samplePerlin` as clean Zig — the auto-translated C code generates better machine code |
| -8.7% | Union climate bounds single-pass — merging per-biome bounds makes them too wide, defeating early-exit |
| 0% | SIMD vectorization — not on the hot path (only used in shadow probes) |
| 0% | Cached structure config fast-path — already fast enough |

## How it works

The core biome and structure generation logic comes from
[cubiomes](https://github.com/Cubitect/cubiomes) by Cubitect, a C library that
reimplements Minecraft's world generation. This project auto-translated cubiomes
into Zig (`src/cubiomes_port.zig`, ~72K lines) and then applied targeted
optimizations to the hot paths — climate parameter early-exit, biome tree
rewrites, deferred spawn computation, and cached multi-biome scanning.

The search loop iterates over seeds, evaluates structure placement via region
coordinate math, and samples biome noise to check constraints. A boolean
expression engine lets you compose constraints with `and`/`or`/`not` logic.

## License

The seed finder code is released under the [Unlicense](https://unlicense.org/)
(public domain).

The vendored cubiomes library (`lib/cubiomes/`) is under the
[MIT License](lib/cubiomes/LICENSE), copyright 2020 Cubitect.
