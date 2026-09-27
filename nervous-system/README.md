# Herdr Nervous System

Dockerized deployment of the herdr nervous system with Hermes (brain) connected to Microsoft Teams and Omp (worker-spawner).

## Architecture

```
┌─────────────────────────────────────────────┐
│           nervous-system container           │
│                                             │
│  ┌──────────┐    ┌──────────────────────┐   │
│  │ Herdr     │    │  W1: Nervous System  │   │
│  │ Server    │    │  ┌────────────────┐  │   │
│  │ (headless)│    │  │ hermes gateway │  │   │
│  │           │    │  │ (Teams webhook)│  │   │
│  │ Socket    │    │  └────────────────┘  │   │
│  │ API       │    │                      │   │
│  │           │    │  W2: Workers         │   │
│  │           │    │  ┌────────────────┐  │   │
│  │           │    │  │ omp (spawner)  │  │   │
│  │           │    │  │ worker-1       │  │   │
│  │           │    │  │ worker-2       │  │   │
│  │           │    │  └────────────────┘  │   │
│  └──────────┘    └──────────────────────┘   │
└───────────┬─────────────────────────────────┘
            │
    ┌───────┴───────┐
    │  Teams bot    │ ← @Hermes messages
    │  :3978/api    │
    └───────────────┘
```

## Quick Start

### 1. Configure Teams (one-time setup)

Register a Teams bot and get credentials:

```bash
# Install Teams CLI (provided in the image)
teams login
teams app create \
  --name "Hermes" \
  --endpoint "https://<your-domain>/api/messages"
# Save CLIENT_ID, CLIENT_SECRET, TENANT_ID from the output
```

For local dev, use `devtunnel` for a public HTTPS URL:

```bash
devtunnel create hermes-bot --allow-anonymous
devtunnel port create hermes-bot --port 3978 --is-public
```

### 2. Create `.env` file

```bash
cat > .env << 'EOF'
# Microsoft Teams bot credentials
TEAMS_CLIENT_ID=<your-client-id>
TEAMS_CLIENT_SECRET=<your-client-secret>
TEAMS_TENANT_ID=<your-tenant-id>

# Restrict access to specific Teams users (optional but recommended)
TEAMS_ALLOWED_USERS=12345678-1234-1234-1234-123456789012

# Require @mention in channels (personal chats are always allowed)
TEAMS_REQUIRE_MENTION=true
EOF
```

### 3. Build and run

```bash
docker compose -f nervous-system/docker-compose.yml up -d
```

### 4. Verify

```bash
# Check all services are running
docker compose -f nervous-system/docker-compose.yml ps

# Check Hermes gateway logs
docker compose -f nervous-system/docker-compose.yml logs -f nervous-system

# Control Omp/workers via herdr CLI
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent list
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent prompt omp "Review the PR changes." --wait --timeout 300000
```

### 5. Chat with Hermes

Open Microsoft Teams and message @Hermes in any chat or channel.

## Stopping

```bash
docker compose -f nervous-system/docker-compose.yml down
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TEAMS_CLIENT_ID` | Yes | Azure AD app client ID |
| `TEAMS_CLIENT_SECRET` | Yes | Azure AD app client secret |
| `TEAMS_TENANT_ID` | Yes | Azure AD tenant ID |
| `TEAMS_ALLOWED_USERS` | No | Space-separated AAD object IDs |
| `TEAMS_REQUIRE_MENTION` | No | Require @mention in channels (default: `true`) |
| `HERMES_MODEL_PROVIDER` | No | Model provider (default: `custom`) |
| `HERMES_MODEL_BASE_URL` | No | Model API endpoint (default: `http://llama:8080/v1`) |
| `HERMES_MODEL_DEFAULT` | No | Default model name |

### Helm/Model Provider

The nervous system uses llama.cpp for local model inference. Point to your own model:

```yaml
# In docker-compose.yml
command:
  - --model
  - /models/your-model.gguf
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image build — herdr + Node.js + bun + Hermes Agent + Omp + Teams CLI |
| `config.toml` | Herdr headless server config |
| `init.sh` | Startup script (server → workspaces → hermes gateway + omp agents) |
| `docker-compose.yml` | Full stack: llama.cpp + nervous-system with Teams webhook |

## Persistence

Named volumes preserve state across restarts:

- `herdr-data` — herdr config, sessions, agent state
- `workspace` — shared workspace directory
- `models` — llama.cpp model files
