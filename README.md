# Toolbox

A collection of ready-to-use development environments, distributed as container images.

## What's Available

| Tool | Description | Image |
|------|-------------|-------|
| **NvChad** | A batteries-included Neovim + Zellij + OpenCode dev environment | `ghcr.io/spoletum/toolbox-nvchad` |

## Quick Start

Pull and run the latest image:

```bash
# Using Docker
docker pull ghcr.io/spoletum/toolbox-nvchad:latest

# Using Podman
podman pull ghcr.io/spoletum/toolbox-nvchad:latest
```

## Project Structure

```
.
├── nvchad/                     # NvChad development environment
│   ├── Dockerfile              # Multi-platform container image
│   ├── Makefile                # Local build helpers
│   ├── zellij-layout.kdl       # Default Zellij layout
│   └── README.md               # Usage guide
├── .github/workflows/          # CI/CD pipelines
│   └── publish-nvchad.yml      # Build and publish container
└── AGENTS.md                   # Project notes for contributors
```

## Building Locally

Each tool has its own `Makefile` for local builds. See the individual `README.md` files inside each tool's folder.

## Contributing

1. Make changes to the relevant `Dockerfile` or config.
2. Open a Pull Request — the CI will build and cache the image without publishing it.
3. Once merged, tag a release (`v*`) to publish the image to GHCR.
