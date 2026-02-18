# Justfile for minecraft-seed-finder

DEV_IMAGE := "minecraft-seed-finder-dev"
DEV_VOLUME := "minecraft-seed-finder-claude-credentials"
CLAUDE_OAUTH := env_var_or_default("CLAUDE_CODE_CONTAINER_OAUTH_TOKEN", "")

default:
    @just --list

# Differential fuzzing against extracted C reference
fuzz ROUNDS="8":
    scripts/diff_fuzz.sh {{ROUNDS}}

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
