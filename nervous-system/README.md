# Herdr Nervous System

Dockerized deployment of the herdr nervous system with Hermes (brain) and Omp (worker-spawner).

## Architecture

```
┌─────────────────────────────────────────────┐
│           nervous-system container           │
│                                             │
│  ┌──────────┐    ┌──────────────────────┐   │
│  │ Herdr     │    │  W1: Nervous System  │   │
│  │ Server    │    │  ┌────────────────┐  │   │
│  │ (PID 1)   │    │  │ hermes (brain) │  │   │
│  │           │    │  └────────────────┘  │   │
│  │ Socket    │    │                      │   │
│  │ API       │    │  W2: Workers         │   │
│  │           │    │  ┌────────────────┐  │   │
│  │           │    │  │ omp (spawner)  │  │   │
│  │           │    │  │ worker-1       │  │   │
│  │           │    │  │ worker-2       │  │   │
│  │           │    │  └────────────────┘  │   │
│  └──────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────┘
```

## Quick Start

### Build and run

```bash
cd nervous-system
docker compose up -d
```

### Verify

```bash
docker compose exec nervous-system herdr workspace list
docker compose exec nervous-system herdr agent list
```

### Interact with agents

```bash
# Prompt Hermes (brain)
docker compose exec nervous-system herdr agent prompt hermes "Analyze the codebase and report top issues."

# Hermes will coordinate with Omp to spawn workers as needed
```

### View agent output

```bash
# Read what Hermes last output
docker compose exec nervous-system herdr agent read hermes --source detection --lines 50

# List all agents and their states
docker compose exec nervous-system herdr agent list --json
```

### Stop

```bash
docker compose down
```

## Configuration

Edit `nervous-system/config.toml` before building to customize herdr behavior.

## Persistence

Named volumes preserve state across restarts:

- `herdr-data` — herdr config, sessions, and agent state
- `workspace` — shared workspace directory

## Networking

The herdr socket is accessible inside the container. To connect from the host:

```bash
# Option 1: Docker exec
docker exec -it nervous-system herdr agent prompt hermes "Hello from host"

# Option 2: Bind mount the socket
# (Add to docker-compose.yml: - herdr-sock:/tmp/herdr.sock)
```

## Image

Built with multi-platform support (`linux/amd64`, `linux/arm64`).

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/spoletum/toolbox-herdr-nervous-system:latest \
  --push .
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image build — herdr + Node.js + bun + agents |
| `config.toml` | Herdr server configuration |
| `init.sh` | Startup script — launches server + workspaces + agents |
| `docker-compose.yml` | Container orchestration |
