# Toolbox Project Agent Notes

## Build System

- GitHub Actions workflow: `.github/workflows/publish-nvchad.yml`
- Docker image built with Buildx and multi-platform support (linux/amd64, linux/arm64)
- Dockerfile location: `nvchad/Dockerfile`

## Caching Strategy

The pipeline uses multiple layers of caching to minimize build times:

### 1. GitHub Actions Cache (GHA) for Docker Layers
- `cache-from: type=gha` and `cache-to: type=gha,mode=max` are configured in the workflow
- This persists Docker image layers across builds, so unchanged layers do not rebuild
- PR builds also populate this cache, keeping it warm between releases

### 2. BuildKit Cache Mounts (Package Manager Caches)
The Dockerfile uses `--mount=type=cache` directives to persist package manager caches inside the BuildKit cache:
- **APT**: `/var/cache/apt` and `/var/lib/apt/lists` — avoids re-downloading package indexes and deb files on rebuilds
- **npm**: `/root/.npm` — caches npm registry metadata and tarballs for global installs (tree-sitter-cli, language servers)
- **Go modules**: `/root/go/pkg/mod` — caches Go module downloads for `go install`

These mounts require the `# syntax=docker/dockerfile:1` header (already present) and are exported alongside layers by `type=gha`.

### 3. Cache Warming via Pull Requests
- The workflow triggers on `pull_request` when `nvchad/**` or the workflow itself changes
- PR builds use `push: false`, so they build and cache layers without publishing
- This ensures the GHA cache is primed before tag releases, dramatically speeding them up

## Important Notes

- Do **not** use cache mounts for NvChad plugins (`/root/.local/share/nvim/lazy`)
  - We intentionally bake plugins into the image layer so containers start instantly
  - A cache mount would leave plugins out of the final image
- The `sharing=locked` option on APT cache mounts prevents concurrent apt access during multi-platform builds
