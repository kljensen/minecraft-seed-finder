# Justfile for minecraft-seed-finder

DEV_IMAGE := "minecraft-seed-finder-dev"
DEV_VOLUME := "minecraft-seed-finder-claude-credentials"
CLAUDE_OAUTH := env_var_or_default("CLAUDE_CODE_CONTAINER_OAUTH_TOKEN", "")

default:
    @just --list

# Build for native platform
build OPT="ReleaseFast":
    zig build -Doptimize={{OPT}}

# Build for macOS (native or cross-compile)
build-mac OPT="ReleaseFast":
    zig build -Dtarget=aarch64-macos -Doptimize={{OPT}}

# Build for Linux (native or cross-compile)
build-linux OPT="ReleaseFast":
    zig build -Dtarget=aarch64-linux -Doptimize={{OPT}}

# Build for both macOS and Linux
build-all OPT="ReleaseFast":
    just build-mac {{OPT}}
    just build-linux {{OPT}}

# Build and run all Zig tests
test OPT="Debug":
    zig build test --build-file build.zig -Doptimize={{OPT}}

# Generate parity vectors with explicit knobs
gen-parity \
    OPT="ReleaseFast" \
    SEEDS="64" \
    BIOMES="128" \
    RADIUS="2" \
    SPAN="4096" \
    SALT="0" \
    THREADS="0" \
    SIMD="0" \
    PRETTY="1" \
    OUT="tests/golden/parity_vectors.json":
    PARITY_SEED_COUNT={{SEEDS}} \
    PARITY_BIOME_SAMPLES={{BIOMES}} \
    PARITY_REGION_RADIUS={{RADIUS}} \
    PARITY_BIOME_SPAN={{SPAN}} \
    PARITY_SEED_SALT={{SALT}} \
    PARITY_THREADS={{THREADS}} \
    PARITY_SIMD={{SIMD}} \
    PARITY_PRETTY={{PRETTY}} \
    PARITY_OUTPUT_PATH={{OUT}} \
    zig build gen-parity-vectors --build-file build.zig -Doptimize={{OPT}}

# Same as gen-parity, but enables per-version timing instrumentation
gen-parity-timing \
    OPT="ReleaseFast" \
    SEEDS="64" \
    BIOMES="128" \
    RADIUS="2" \
    SPAN="4096" \
    SALT="0" \
    THREADS="0" \
    SIMD="0" \
    OUT="/tmp/parity-timing.json":
    PARITY_TIMING=1 \
    PARITY_PRETTY=0 \
    PARITY_SEED_COUNT={{SEEDS}} \
    PARITY_BIOME_SAMPLES={{BIOMES}} \
    PARITY_REGION_RADIUS={{RADIUS}} \
    PARITY_BIOME_SPAN={{SPAN}} \
    PARITY_SEED_SALT={{SALT}} \
    PARITY_THREADS={{THREADS}} \
    PARITY_SIMD={{SIMD}} \
    PARITY_OUTPUT_PATH={{OUT}} \
    zig build gen-parity-vectors --build-file build.zig -Doptimize={{OPT}}

# Differential fuzzing against extracted C reference
fuzz ROUNDS="8":
    scripts/diff_fuzz.sh {{ROUNDS}}

# Fast differential fuzz sanity check
fuzz-quick:
    scripts/diff_fuzz.sh 3

# Throughput benchmark across scalar/SIMD/parallel modes
bench:
    scripts/bench_parity.sh

# Build the dev container
dev-build:
    docker build -f Dockerfile.dev -t {{DEV_IMAGE}} .

# Drop into a dev shell
dev-shell: _dev-ensure-image
    @docker run -it --rm --init \
        -v "$(pwd):/workspace" \
        -v "{{DEV_VOLUME}}:/home/vscode/.claude" \
        -v "$HOME/.codex:/home/vscode/.codex" \
        -v "$HOME/.ssh:/home/vscode/.ssh:ro" \
        -v "$HOME/.gitconfig:/home/vscode/.gitconfig:ro" \
        -v "$HOME/.config/gh:/home/vscode/.config/gh:ro" \
        -e ANTHROPIC_API_KEY \
        -e OPENAI_API_KEY \
        -e GITHUB_TOKEN \
        -e TAVILY_API_KEY \
        -e TERM=xterm-256color \
        -e CLAUDE_CODE_OAUTH_TOKEN="{{CLAUDE_OAUTH}}" \
        {{DEV_IMAGE}}

# Run a command in the dev container
dev-run CMD: _dev-ensure-image
    docker run -it --rm --init \
        -v "$(pwd):/workspace" \
        -v "{{DEV_VOLUME}}:/home/vscode/.claude" \
        -e ANTHROPIC_API_KEY \
        -e OPENAI_API_KEY \
        {{DEV_IMAGE}} {{CMD}}

# Rebuild from scratch (no cache)
dev-rebuild:
    docker build -f Dockerfile.dev -t {{DEV_IMAGE}} --no-cache .

# Test container tools
dev-test: _dev-ensure-image
    @docker run --rm {{DEV_IMAGE}} bash -c "\
        echo 'Zig:' && zig version && \
        echo 'Node:' && node --version && \
        echo 'Claude:' && (claude --version 2>/dev/null || echo 'installed') && \
        echo 'gcc:' && gcc --version | head -1 && \
        echo 'cmake:' && cmake --version | head -1 && \
        echo 'Helix:' && hx --version && \
        echo 'just:' && just --version \
    "

# Clean up dev image
dev-clean:
    docker rmi {{DEV_IMAGE}} 2>/dev/null || true

# Clean credentials volume
dev-clean-credentials:
    docker volume rm {{DEV_VOLUME}} 2>/dev/null || true

# Build dev image if it doesn't exist
_dev-ensure-image:
    @docker image inspect {{DEV_IMAGE}} >/dev/null 2>&1 || just dev-build
