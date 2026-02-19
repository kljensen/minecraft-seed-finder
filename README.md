# Bedrock Seed Finder (Zig)

Searches Minecraft Bedrock seeds by biome and structure constraints.

## Build

```sh
zig build
```

## Test

```sh
zig build test
```

## Examples

```sh
zig build run -- --count 3 --version 1.21.1 --max-seed 1000000 \
  --require-biome "flower forest:100" \
  --require-biome "extreme hills:100" \
  --require-structure "village:600"
```

Boolean filter expressions:

```sh
zig build run -- --count 5 --max-seed 500000 \
  --require-biome "plains:96" \
  --require-structure "village:400" \
  --require-structure "mansion:1200" \
  --where "b1 and (s1 or s2)"
```

Rank top matches across a range:

```sh
zig build run -- --count 20 --ranked --top-k 10 --max-seed 2000000 \
  --require-biome "plains:96" \
  --format jsonl
```

Resume long scans with checkpointing:

```sh
zig build run -- --count 10 --max-seed 50000000 \
  --require-structure "village:500" \
  --checkpoint /tmp/seedfinder.ckpt \
  --checkpoint-every 200000 \
  --progress-every 500000

zig build run -- --count 10 --max-seed 50000000 \
  --require-structure "village:500" \
  --checkpoint /tmp/seedfinder.ckpt \
  --resume
```

Import a seed directly from a world save:

```sh
zig build run -- --count 3 --level-dat /path/to/level.dat \
  --require-structure "village:500"
```

## CLI

```text
seed-finder --count <N> [options]

--version <1.18|1.19|1.20|1.21.1>
--start-seed <u64>
--max-seed <u64>
--count <N>
--require-biome <name:radius>
--require-structure <name:radius>
--where <expr>                    # boolean expression over bN/sN/cN keys
--anchor <x:z>                    # evaluate constraints around fixed location
--level-dat <path>                # import start seed from Java/Bedrock level.dat
--ranked                          # keep top results by score across range
--top-k <N>                       # ranked result count (defaults to --count)
--format <text|jsonl|csv>         # output format
--progress-every <N>
--checkpoint <path>
--checkpoint-every <N>
--resume
--output <path>
```

Expression grammar:

- operators: `and`, `or`, `not` (`&&`, `||`, `!` also supported)
- grouping: parentheses
- identifiers:
`b1`, `b2`, ... in the order `--require-biome` appears
`s1`, `s2`, ... in the order `--require-structure` appears
`c1`, `c2`, ... in overall constraint order
