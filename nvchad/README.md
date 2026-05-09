# NvChad Development Environment

A containerized development environment with **Neovim** (NvChad), **Zellij**, **OpenCode**, and a full language server toolchain.

## What's Inside

- **Neovim** (latest release) with [NvChad](https://nvchad.com) pre-configured
- **Zellij** — terminal multiplexer with a dev-focused default layout
- **OpenCode** — AI assistant (running in its own pane)
- **Go**, **Node.js 22**, **Python 3**
- **Language Servers**: `gopls`, `pyright`, `ts_ls`, `@tailwindcss/language-server`
- **Tools**: `lazygit`, `ripgrep`, `fzf`, `fd`, `tree-sitter`

## Quick Start

### Run from the registry

```bash
# Docker
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.config/opencode:/root/.config/opencode \
  ghcr.io/spoletum/toolbox-nvchad:latest

# Podman
podman run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.config/opencode:/root/.config/opencode \
  ghcr.io/spoletum/toolbox-nvchad:latest
```

### Default Layout

When the container starts, Zellij opens with three panes:

```
┌─────────────┬─────────────┐
│             │             │
│  OpenCode   │             │
│             │    Neovim   │
├─────────────┤             │
│             │             │
│    Shell    │             │
└─────────────┴─────────────┘
```

- **Left top**: OpenCode AI assistant
- **Left bottom**: Bash shell
- **Right**: Neovim (opens in `/workspace`)

## Build Locally

```bash
# Build for your current platform
make nvchad

# Build for a specific platform
make nvchad-amd64
make nvchad-arm64

# Build with a different Ubuntu base
make nvchad UBUNTU_TAG=22.04
```

> Note: Local builds use `--no-cache` to ensure a clean image. For faster rebuilds during development, remove `--no-cache` from the `Makefile`.

## Volumes

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| `$(pwd)` | `/workspace` | Your project code |
| `~/.config/opencode` | `/root/.config/opencode` | OpenCode configuration |

Additional state directories (`/root/.local/share/opencode`, `/root/.local/state/opencode`, `/root/.cache/opencode`) are declared as volumes so they persist across container restarts if you name your container.

## Customizing

### Neovim config

The image pre-installs a few NvChad plugins and settings:

- **Clipboard**: OSC52 (works over SSH, no host dependencies)
- **Tree-sitter**: Go, Python, JavaScript, TypeScript, TSX, Lua, Vim, Markdown
- **LSP**: gopls, pyright, ts_ls
- **OpenCode.nvim**: Keymaps under `<leader>o`

You can override any of this by mounting your own config over `/root/.config/nvim`.

### Zellij layout

The default layout is baked in at `/root/.config/zellij/layouts/dev.kdl`. Mount your own `.kdl` to change the pane arrangement:

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ./my-layout.kdl:/root/.config/zellij/layouts/dev.kdl:ro \
  ghcr.io/spoletum/toolbox-nvchad:latest
```

## Troubleshooting

**Fonts look weird?** Make sure your terminal supports Nerd Fonts (NvChad uses icons that require them).

**OpenCode not responding?** It may be initializing on first run. Wait a moment or check the pane logs.
