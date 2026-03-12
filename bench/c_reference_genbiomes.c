/*
 * c_reference_genbiomes.c -- Alternative "cubiomes C" baseline.
 *
 * Uses genBiomes() over a rectangular biome-scale region rather than
 * individual getBiomeAt() calls per circular grid point.  This matches
 * how a typical cubiomes-based seed finder would be written following
 * the cubiomes examples.
 *
 * Key differences from c_reference.c:
 *   - Calls genBiomes(scale=4) once per seed to fill a 151×151 biome grid
 *     (covering ±300 blocks at 4-block resolution = ±75 biome coords)
 *   - Iterates the returned array looking for the target biome
 *   - Still uses the same impossible-fail short-circuit and min_count logic
 *   - Structure check unchanged (same region math, getStructurePos)
 *
 * Build:
 *   cc -O3 -fwrapv -o bench/c_reference_genbiomes bench/c_reference_genbiomes.c \
 *       lib/cubiomes/noise.c lib/cubiomes/biomes.c lib/cubiomes/layers.c \
 *       lib/cubiomes/biomenoise.c lib/cubiomes/generator.c \
 *       lib/cubiomes/finders.c lib/cubiomes/util.c lib/cubiomes/quadbase.c \
 *       -Ilib/cubiomes -lm
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <math.h>
#include <time.h>

#include "generator.h"
#include "finders.h"
#include "biomes.h"

static int floor_div(int a, int b)
{
    int q = a / b;
    if ((a ^ b) < 0 && q * b != a) q--;
    return q;
}

static int64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

static int biome_id_from_name(const char *name)
{
#define B(n, id) if (strcmp(name, n) == 0) return id;
    B("cherry_grove",      cherry_grove)
    B("flower_forest",     flower_forest)
    B("windswept_hills",   windswept_hills)
    B("mountains",         windswept_hills)
    B("plains",            plains)
    B("forest",            forest)
    B("jungle",            jungle)
    B("desert",            desert)
    B("ocean",             ocean)
    B("snowy_plains",      snowy_plains)
    B("ice_spikes",        ice_spikes)
    B("mushroom_fields",   mushroom_fields)
    B("meadow",            meadow)
    B("jagged_peaks",      jagged_peaks)
    B("lush_caves",        lush_caves)
    B("deep_dark",         deep_dark)
    B("swamp",             swamp)
    B("beach",             beach)
    B("taiga",             taiga)
    B("birch_forest",      birch_forest)
    B("dark_forest",       dark_forest)
    B("savanna",           savanna)
    B("badlands",          badlands)
    B("mangrove_swamp",    mangrove_swamp)
    B("snowy_taiga",       snowy_taiga)
    B("grove",             grove)
    B("frozen_ocean",      frozen_ocean)
    B("warm_ocean",        warm_ocean)
    B("deep_ocean",        deep_ocean)
    B("stony_peaks",       stony_peaks)
    B("frozen_peaks",      frozen_peaks)
#undef B
    return -1;
}

static int structure_id_from_name(const char *name)
{
    if (strcmp(name, "village") == 0)        return Village;
    if (strcmp(name, "outpost") == 0)        return Outpost;
    if (strcmp(name, "ancient_city") == 0)   return Ancient_City;
    if (strcmp(name, "desert_pyramid") == 0) return Desert_Pyramid;
    if (strcmp(name, "igloo") == 0)          return Igloo;
    if (strcmp(name, "jungle_pyramid") == 0) return Jungle_Temple;
    if (strcmp(name, "mansion") == 0)        return Mansion;
    if (strcmp(name, "monument") == 0)       return Monument;
    if (strcmp(name, "ocean_ruin") == 0)     return Ocean_Ruin;
    if (strcmp(name, "ruined_portal") == 0)  return Ruined_Portal;
    if (strcmp(name, "shipwreck") == 0)      return Shipwreck;
    if (strcmp(name, "swamp_hut") == 0)      return Swamp_Hut;
    if (strcmp(name, "treasure") == 0)       return Treasure;
    return -1;
}

#define MAX_BIOMES     8
#define MAX_STRUCTURES 8

typedef struct {
    int      biome_id;
    int      radius;      /* block radius */
    int      min_count;
    int64_t  radius2;
    /* biome-coordinate radius: ceil(radius/4) */
    int      bcoord_radius;
} BiomeReq;

typedef struct {
    int      structure_id;
    int      mc;
    int      radius;
    int64_t  radius2;
    StructureConfig cfg;
} StructureReq;

/*
 * Use genBiomes() at scale=4 (biome coordinates, 1 unit = 4 blocks) over
 * the full square bounding box.  Count the target biome within the box;
 * we do NOT restrict to the circle (no circular filter) — this is the
 * naive "get the whole region" approach.
 */
static int biome_matches_genbiomes(Generator *g, int ax, int az,
                                   int biome_id, int bcoord_radius,
                                   int min_count)
{
    int side = 2 * bcoord_radius + 1;  /* side length in biome coords */
    Range r;
    r.scale = 4;
    r.x = ax/4 - bcoord_radius;
    r.z = az/4 - bcoord_radius;
    r.sx = side;
    r.sz = side;
    r.y = 15;    /* surface-ish */
    r.sy = 1;

    int *ids = allocCache(g, r);
    if (!ids) return 0;
    if (genBiomes(g, ids, r) != 0) {
        free(ids);
        return 0;
    }

    int total = side * side;
    int count = 0;
    for (int i = 0; i < total; i++) {
        if (ids[i] == biome_id) {
            count++;
            if (count >= min_count) {
                free(ids);
                return 1;
            }
        }
        int remaining = total - i - 1;
        if (count + remaining < min_count) {
            free(ids);
            return 0;
        }
    }
    free(ids);
    return 0;
}

static int structure_matches(Generator *g, uint64_t seed, int ax, int az,
                              StructureReq *req)
{
    int mc = req->mc;
    int radius = req->radius;
    int64_t r2 = req->radius2;
    StructureConfig *cfg = &req->cfg;

    int min_chunk_x = floor_div(ax - radius - 8, 16);
    int max_chunk_x = floor_div(ax + radius - 8, 16);
    int min_chunk_z = floor_div(az - radius - 8, 16);
    int max_chunk_z = floor_div(az + radius - 8, 16);

    int spacing = (int)cfg->regionSize;
    int min_reg_x = floor_div(min_chunk_x - (spacing - 1), spacing);
    int max_reg_x = floor_div(max_chunk_x, spacing);
    int min_reg_z = floor_div(min_chunk_z - (spacing - 1), spacing);
    int max_reg_z = floor_div(max_chunk_z, spacing);

    for (int rz = min_reg_z; rz <= max_reg_z; rz++) {
        for (int rx = min_reg_x; rx <= max_reg_x; rx++) {
            Pos pos;
            if (!getStructurePos(req->structure_id, mc, seed, rx, rz, &pos))
                continue;
            int64_t dx = pos.x - ax;
            int64_t dz = pos.z - az;
            if (dx*dx + dz*dz > r2) continue;
            if (!isViableStructurePos(req->structure_id, g, pos.x, pos.z, 0))
                continue;
            if (!isViableStructureTerrain(req->structure_id, g, pos.x, pos.z))
                continue;
            return 1;
        }
    }
    return 0;
}

static int parse_biome_spec(const char *spec, BiomeReq *out)
{
    char name[128];
    int n = sscanf(spec, "%127[^:]:%d@%d", name, &out->min_count, &out->radius);
    if (n == 3) { /* name:count@radius */ }
    else {
        n = sscanf(spec, "%127[^:]:%d", name, &out->radius);
        if (n != 2) return 0;
        out->min_count = 1;
    }
    out->biome_id = biome_id_from_name(name);
    if (out->biome_id < 0) { fprintf(stderr, "unknown biome: %s\n", name); return 0; }
    if (out->radius <= 0 || out->min_count <= 0) return 0;
    out->radius2 = (int64_t)out->radius * out->radius;
    out->bcoord_radius = (out->radius + 3) / 4;  /* ceil(radius/4) */
    return 1;
}

static int parse_structure_spec(const char *spec, StructureReq *out, int mc)
{
    char name[128];
    if (sscanf(spec, "%127[^:]:%d", name, &out->radius) != 2) return 0;
    out->structure_id = structure_id_from_name(name);
    if (out->structure_id < 0) {
        fprintf(stderr, "unknown structure: %s\n", name);
        return 0;
    }
    if (out->radius <= 0) return 0;
    out->radius2 = (int64_t)out->radius * out->radius;
    out->mc = mc;
    if (!getStructureConfig(out->structure_id, mc, &out->cfg)) {
        fprintf(stderr, "no structure config for %s\n", name);
        return 0;
    }
    return 1;
}

static int parse_anchor(const char *spec, int *ax, int *az)
{
    return sscanf(spec, "%d:%d", ax, az) == 2;
}

int main(int argc, char **argv)
{
    int mc           = MC_1_21_1;
    int count        = 0;
    int anchor_x     = 0, anchor_z = 0;
    int anchor_set   = 0;
    uint64_t max_seed = UINT64_MAX;

    BiomeReq     biome_reqs[MAX_BIOMES];
    int          n_biomes = 0;
    StructureReq struct_reqs[MAX_STRUCTURES];
    int          n_structs = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--count") == 0 && i+1 < argc) {
            count = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--anchor") == 0 && i+1 < argc) {
            if (!parse_anchor(argv[++i], &anchor_x, &anchor_z)) {
                fprintf(stderr, "bad --anchor\n"); return 1;
            }
            anchor_set = 1;
        } else if (strcmp(argv[i], "--max-seed") == 0 && i+1 < argc) {
            max_seed = (uint64_t)strtoull(argv[++i], NULL, 10);
        } else if (strcmp(argv[i], "--require-biome") == 0 && i+1 < argc) {
            if (n_biomes >= MAX_BIOMES) { fprintf(stderr, "too many biomes\n"); return 1; }
            if (!parse_biome_spec(argv[++i], &biome_reqs[n_biomes])) return 1;
            n_biomes++;
        } else if (strcmp(argv[i], "--require-structure") == 0 && i+1 < argc) {
            if (n_structs >= MAX_STRUCTURES) { fprintf(stderr, "too many structures\n"); return 1; }
            if (!parse_structure_spec(argv[++i], &struct_reqs[n_structs], mc)) return 1;
            n_structs++;
        } else if (strcmp(argv[i], "--version") == 0 && i+1 < argc) {
            const char *v = argv[++i];
            if      (strcmp(v, "1.18") == 0) mc = MC_1_18;
            else if (strcmp(v, "1.19") == 0) mc = MC_1_19;
            else if (strcmp(v, "1.20") == 0) mc = MC_1_20;
            else if (strcmp(v, "1.21.1") == 0 || strcmp(v, "1.21") == 0) mc = MC_1_21_1;
            else { fprintf(stderr, "unknown version: %s\n", v); return 1; }
        } else {
            fprintf(stderr, "unknown arg: %s\n", argv[i]); return 1;
        }
    }

    if (count <= 0) { fprintf(stderr, "--count required\n"); return 1; }
    if (!anchor_set) { fprintf(stderr, "--anchor required\n"); return 1; }

    Generator g;
    setupGenerator(&g, mc, 0);

    int64_t t_start = now_ns();
    uint64_t seed = 0;
    int found = 0;

    while (found < count && seed <= max_seed) {
        applySeed(&g, DIM_OVERWORLD, seed);

        int ok = 1;

        /* Biome-first naive ordering */
        for (int b = 0; b < n_biomes && ok; b++) {
            ok = biome_matches_genbiomes(&g, anchor_x, anchor_z,
                                         biome_reqs[b].biome_id,
                                         biome_reqs[b].bcoord_radius,
                                         biome_reqs[b].min_count);
        }
        for (int s = 0; s < n_structs && ok; s++) {
            ok = structure_matches(&g, seed, anchor_x, anchor_z,
                                   &struct_reqs[s]);
        }

        if (ok) {
            printf("seed=%" PRIu64 "\n", seed);
            fflush(stdout);
            found++;
        }
        seed++;
    }

    int64_t t_end = now_ns();
    double elapsed_s = (t_end - t_start) / 1e9;

    fprintf(stderr,
            "summary: found=%d tested=%" PRIu64 " elapsed=%.3fs seeds/s=%.1f\n",
            found, seed, elapsed_s, seed / elapsed_s);

    return 0;
}
