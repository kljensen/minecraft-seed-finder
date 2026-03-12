# Minecraft Seed Finder

A fast Minecraft seed finder written in Zig, supporting both **Bedrock** and
**Java** editions. Searches seeds by biome and structure constraints using a
pure-Zig port of [cubiomes](https://github.com/Cubitect/cubiomes).

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

## Example seeds

All examples use Bedrock edition (the default), MC 1.21.1, random seed sampling.
Results vary each run — these are real seeds from one run of each command.

**Cherry grove with a village and outpost nearby** (~4 s single-thread)

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

**Eroded badlands with a desert pyramid and village** (~1 s single-thread)

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

**Jagged peaks with a village and outpost** (~10 s with `--threads auto`)

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

### vs C reference

The baseline is `bench/c_reference.c` — a C program with the exact same search
algorithm (same circular biome grid, same impossible-fail short-circuit, same
structure region math) but without the Zig optimisations: it calls cubiomes'
`getBiomeAt()` unconditionally for every grid point (evaluating all 6 climate
parameters each time), and checks biome constraints before structure constraints
(naive ordering). Reproduce with `sh scripts/bench_vs_c_ref.sh`.

Benchmarks anchored at (0,0), single-threaded, Java edition, MC 1.21.1 on
Apple M1 Max. Both tools find identical seeds.

| Query | C reference | seed-finder | Speedup |
|-------|-------------|-------------|---------|
| `cherry_grove:1@300` (500 seeds) | 21.8s | 21.2s | **1.03x** |
| `flower_forest:5@500` + `windswept_hills:5@500` (500 seeds) | 66.6s | 60.8s | **1.10x** |
| `cherry_grove:1@300` + `village:500` (first 5 matches) | 5.4s | 2.8s | **1.93x** |

Two independent speedup sources:

**Climate early-exit** (~1.03–1.10x on biome-only queries): each biome grid
point samples climate parameters one at a time; if an earlier parameter already
rules out the target biome, remaining noise calls are skipped. The gain is
modest for cherry grove because its continentalness and erosion bounds span a
wide range — most rejections come from weirdness and temperature, which are
checked later in the sequence.

**Constraint reordering** (~1.80x on the combined query): the tool checks the
cheap structure constraint first. Seeds that fail the structure check (>97% of
seeds in this query) skip the expensive biome scan entirely. The C reference
uses the naive biome-first order, paying the full biome scan cost for every
seed. Combined with climate early-exit, the two effects multiply to **1.93x**.

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
