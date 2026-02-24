# SIMD-Native Biome Generation Architecture

## Problem

The cubiomes port is auto-translated C - deeply scalar. Every `getBiomeAt()` leaves 75% of SIMD lanes empty on 128-bit NEON (Apple Silicon) or 87.5% empty on 256-bit AVX2.

## Goal

Native Zig biome generation that processes **4+ coordinates or seeds simultaneously**, fully utilizing vector hardware.

## Where Time Goes

```
getBiomeAt()
  └── sampleBiomeNoise()
        ├── perlin3d() × many octaves    ~40%
        ├── simplex2d() × many octaves   ~30%
        └── lerp/interpolation           ~20%
        └── other                        ~10%
```

The noise functions are pure math - perfect SIMD candidates.

## Apple Silicon NEON

Your Mac has 128-bit NEON vectors:
- `@Vector(4, f32)` - 4 floats
- `@Vector(2, f64)` - 2 doubles
- `@Vector(4, i32)` - 4 ints

All basic ops (add, mul, fma, floor, etc.) compile to single instructions.

## Core SIMD Primitives

### Perlin Noise (3D)

The algorithm:
1. Floor coords to get grid cell
2. Compute fractional position within cell
3. Fade curves: `6t⁵ - 15t⁴ + 10t³`
4. Hash grid corners to get gradient indices
5. Dot product of gradient with distance vector
6. Trilinear interpolation of 8 corners

**Vectorized (4 coords at once):**

```zig
const V4 = @Vector(4, f32);
const V4i = @Vector(4, i32);

fn fade4(t: V4) V4 {
    // 6t^5 - 15t^4 + 10t^3 = t^3 * (t * (t * 6 - 15) + 10)
    const six: V4 = @splat(6.0);
    const fifteen: V4 = @splat(15.0);
    const ten: V4 = @splat(10.0);
    return t * t * t * (t * (t * six - fifteen) + ten);
}

fn lerp4(a: V4, b: V4, t: V4) V4 {
    return a + t * (b - a);  // single FMA on good hardware
}

fn perlin3d_x4(
    perm: *const [512]u8,
    xs: V4, ys: V4, zs: V4
) V4 {
    // Integer grid coords
    const xi = @as(V4i, @intFromFloat(@floor(xs))) & @as(V4i, @splat(255));
    const yi = @as(V4i, @intFromFloat(@floor(ys))) & @as(V4i, @splat(255));
    const zi = @as(V4i, @intFromFloat(@floor(zs))) & @as(V4i, @splat(255));

    // Fractional coords
    const xf = xs - @floor(xs);
    const yf = ys - @floor(ys);
    const zf = zs - @floor(zs);

    // Fade curves
    const u = fade4(xf);
    const v = fade4(yf);
    const w = fade4(zf);

    // Hash lookups (this is the tricky part - need gathers)
    // For each of 8 corners, for each of 4 coords = 32 lookups
    // ... see "Handling Gathers" below

    // Gradient dots + trilinear interp
    // ...
}
```

### Handling Gathers (Permutation Table Lookups)

The challenge: `perm[xi]` where `xi` is a vector. Options:

**A. Scalar extract/insert (simple, ~okay perf):**
```zig
fn gather4(table: []const u8, indices: V4i) V4i {
    return V4i{
        table[@intCast(indices[0])],
        table[@intCast(indices[1])],
        table[@intCast(indices[2])],
        table[@intCast(indices[3])],
    };
}
```

**B. Compute permutation inline (no memory, more ALU):**

The permutation table comes from hashing. We could compute `hash(seed, coord)` directly instead of table lookup. More ALU but no cache misses.

**C. Vectorized hash function:**

```zig
fn hash4(seed: V4i, x: V4i, y: V4i, z: V4i) V4i {
    // Combine coords with seed using vectorized mixing
    var h = seed ^ (x *% @as(V4i, @splat(374761393)));
    h = h ^ (y *% @as(V4i, @splat(668265263)));
    h = h ^ (z *% @as(V4i, @splat(1274126177)));
    // ... more mixing
    return h;
}
```

This is the **key insight**: replace table lookups with computed hashes. More math, but math is free compared to memory stalls.

### Simplex Noise (2D)

Simplex uses a triangular grid instead of square:
1. Skew input to simplex grid
2. Determine which simplex (triangle) we're in
3. Only 3 corners to evaluate (vs 4 for square, 8 for cube)
4. Sum contributions from corners

**Advantage:** Fewer gradient evaluations = less work per sample.

```zig
fn simplex2d_x4(perm: *const [512]u8, xs: V4, ys: V4) V4 {
    const F2: V4 = @splat(0.5 * (@sqrt(3.0) - 1.0));
    const G2: V4 = @splat((3.0 - @sqrt(3.0)) / 6.0);

    // Skew
    const s = (xs + ys) * F2;
    const i = @floor(xs + s);
    const j = @floor(ys + s);

    // Unskew
    const t = (i + j) * G2;
    const x0 = xs - (i - t);
    const y0 = ys - (j - t);

    // Determine simplex
    // ... vectorized comparisons give us masks

    // Contributions from 3 corners
    // ...
}
```

## Data Layout: AoS vs SoA

**Current (Array of Structs):**
```zig
// Processing 4 seeds means 4 separate Generator structs
gen[0].getBiomeAt(x, z);
gen[1].getBiomeAt(x, z);
gen[2].getBiomeAt(x, z);
gen[3].getBiomeAt(x, z);
```

**SIMD-native (Struct of Arrays):**
```zig
const Generator4 = struct {
    // Seeds as vector
    seeds: @Vector(4, u64),

    // Could have 4 perm tables, or compute inline
    // ...
};

fn getBiomeAt_x4(g: *Generator4, x: i32, z: i32) @Vector(4, i32) {
    // All 4 seeds evaluated at same coord, returns 4 biome IDs
}
```

**Or coords as SoA:**
```zig
fn getBiomeAt_coords4(g: *Generator, xs: V4i, zs: V4i) V4i {
    // Single seed evaluated at 4 coords, returns 4 biome IDs
}
```

## Implementation Phases

### Phase 1: Native Zig Noise (scalar, no SIMD)

Rewrite from scratch in clean idiomatic Zig:
- `perlin2d`, `perlin3d`
- `simplex2d`
- Octave summation (fbm)
- Biome parameter sampling (temperature, humidity, etc.)

Test against cubiomes golden vectors for correctness.

**Deliverable:** Drop-in replacement for cubiomes noise, same interface, clean code.

### Phase 2: SIMD Noise Primitives

Create `_x4` variants:
- `perlin2d_x4`, `perlin3d_x4`
- `simplex2d_x4`
- `fbm_x4` (octave summer)

**Deliverable:** Vectorized noise that processes 4 coords per call.

### Phase 3: SIMD Biome Sampling

Wire up the noise to biome ID computation:
- Sample climate parameters (temp, humidity, etc.) with SIMD
- Biome lookup from parameters (may need to stay scalar due to branching)

**Deliverable:** `getBiomeAt_x4` that returns 4 biome IDs.

### Phase 4: SIMD Seed Batching

Process 4 different seeds simultaneously:
- Compute or store 4 permutation tables
- Run same coord through 4 different world gens
- Check constraints on all 4

**Deliverable:** Main search loop processes 4 seeds per iteration.

### Phase 5: Hybrid Coord + Seed

For the biome count scan, we check many coords per seed:
- Outer loop: 4 seeds at a time
- Inner loop: 4 coords at a time
- = 16 biome lookups per iteration

**Deliverable:** Maximum throughput scanner.

## Benchmarking Strategy

At each phase, measure:
1. Single-coord throughput (biomes/sec)
2. Scan throughput (seeds/sec for a typical query)
3. Verify correctness against golden vectors

Target: **10-20x** improvement over current scalar C port.

## Minecraft Biome Specifics

The biome selection uses these noise parameters:

| Parameter | Noise Type | Octaves | Range |
|-----------|------------|---------|-------|
| Temperature | Perlin | 2 | -1 to 1 |
| Humidity | Perlin | 2 | -1 to 1 |
| Continentalness | Perlin | 4+ | -1 to 1 |
| Erosion | Perlin | 4+ | -1 to 1 |
| Weirdness | Perlin | 4+ | -1 to 1 |
| PV | Derived | - | from weirdness |
| Depth | Derived | - | for caves |

These 5+ noise samples per coord are the hot path. Each octave is independent = parallelizable.

## Zig SIMD Syntax Reference

```zig
// Declare vector type
const V4 = @Vector(4, f32);

// Splat scalar to all lanes
const fours: V4 = @splat(4.0);

// Element-wise ops just work
const sum = a + b;
const prod = a * b;

// Comparisons return bool vectors
const mask = a > b;  // @Vector(4, bool)

// Select based on mask
const result = @select(f32, mask, a, b);

// Reductions
const total = @reduce(.Add, v);
const any_true = @reduce(.Or, bool_vec);

// Shuffle/swizzle
const reversed = @shuffle(f32, v, undefined, [4]i32{3, 2, 1, 0});

// Int <-> Float
const ints = @as(V4i, @intFromFloat(floats));
const floats = @as(V4, @floatFromInt(ints));
```

## Questions to Resolve

1. **Permutation table vs computed hash?**
   - Benchmark both approaches
   - Computed avoids memory but needs good hash

2. **f32 vs f64?**
   - Minecraft uses doubles internally
   - f32 gives 2x SIMD width but may have precision issues
   - Test if f32 matches biome output

3. **Optimal batch size?**
   - 4-wide is natural for NEON/SSE
   - Could go 8-wide with two registers
   - Measure register pressure

4. **Early-exit for biome scanning?**
   - Currently we scan entire radius
   - Could early-exit once min_count is reached
   - But early-exit breaks SIMD batching - tradeoff
