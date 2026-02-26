# Minecraft Seed Finder

A fast Minecraft Bedrock seed finder written in Zig. Searches seeds by biome and
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

Find an alpine village — flower forest and meadow at spawn, jagged peaks
towering nearby, a village and stronghold within walking distance:

```sh
zig build run -Doptimize=ReleaseFast -- \
  --random --count 3 \
  --require-biome "flower_forest:2@50" \
  --require-biome "meadow:2@80" \
  --require-biome "jagged_peaks:3@350" \
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
zig build test
```

## Performance

The cubiomes port was iteratively profiled and optimized over 10 rounds. All
measurements used a hard biome+structure query (`flower_forest:5@500` +
`extreme_hills:5@500` + `village:600`, 500K seeds, anchored).

### What worked

| Speedup | Optimization |
|---------|-------------|
| 4.3x | Climate parameter early-exit — skip remaining noise calls when earlier parameters already rule out the target biome |
| 1.56x | Defer `getSpawn` for anchor queries — spawn was 36% of per-seed cost and wasted on seeds that fail constraints |
| 1.06x | Cached sequential multi-biome scan with leaf-level feasibility — share noise cache across biome constraints, tighter per-leaf bounds |
| 1.04x | Rewrite `get_resulting_node`/`get_np_dist` biome tree walk as clean idiomatic Zig |
| 1.04x | Structure eval: region sorting by distance + constraint cost ordering |

**Net result**: **84s → 18s** on a hard biome+structure query (4.5x).

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
