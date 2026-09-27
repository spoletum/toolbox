# Toolbox

A collection of ready-to-use development environments, distributed as container images.

## What's Available

| Tool | Description | Image |
|------|-------------|-------|
| **NvChad** | A batteries-included Neovim + Zellij + OpenCode dev environment | `ghcr.io/spoletum/toolbox-nvchad` |
| **Herdr Pi** | A Homebrew-based Linux environment with the pi coding agent | `ghcr.io/spoletum/toolbox-herdr-pi` |

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
├── herdr/
│   └── pi/                     # Homebrew environment with the pi coding agent
│       ├── Dockerfile
│       ├── Makefile
│       ├── models.json         # Pi's local llama.cpp provider
│       └── README.md           # Compose-based usage instructions
├── .github/workflows/          # CI/CD pipelines
│   ├── publish-nvchad.yml      # Build and publish toolbox-nvchad
│   └── publish-herdr-pi.yml    # Build and publish toolbox-herdr-pi
└── AGENTS.md                   # Project notes for contributors
```

## Building Locally

Each tool has its own build helper. See the individual `README.md` files for usage. Herdr Pi is started from the repository root with Docker Compose (`make up`, then `make pi`) so it can reach its llama.cpp service.

## Contributing

1. Make changes to the relevant `Dockerfile` or config.
2. Open a Pull Request — the CI will build and cache the image without publishing it.
3. Once merged, tag a release (`v*`) to publish the image to GHCR.
