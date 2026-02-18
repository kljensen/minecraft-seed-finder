# Bedrock Seed Finder (Zig)

Searches Minecraft Bedrock seeds by biome and structure constraints near spawn.

## Build

```sh
zig build
```

## Test

```sh
zig build test
```

## Example

```sh
zig build run -- --count 3 --version 1.21.1 \
  --require-biome "flower forest:100" \
  --require-biome "extreme hills:100" \
  --require-structure "village:600"
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
--output <path>
```
