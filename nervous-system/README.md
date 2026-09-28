# Herdr Nervous System

Dockerized deployment of the herdr nervous system with Hermes (brain) as a herdr agent and Teams integration via webhook handler.

## Architecture

```
┌─────────────────────────────────────────────┐
│           nervous-system container           │
│                                             │
│  ┌──────────┐    ┌──────────────────────┐   │
│  │ Herdr     │    │  W1: Nervous System  │   │
│  │ Server    │    │  ┌────────────────┐  │   │
│  │           │    │  │ hermes agent   │  │   │
│  │           │    │  │ (lifecycle ✓)  │  │   │
│  │           │    │  └────────────────┘  │   │
│  │           │    │                      │   │
│  │           │    │  W2: Workers         │   │
│  │           │    │  ┌────────────────┐  │   │
│  │           │    │  │ omp (spawner)  │  │   │
│  │           │    │  │ worker-1       │  │   │
│  │           │    │  │ worker-2       │  │   │
│  │           │    │  └────────────────┘  │   │
│  └──────────┘    └──────────────────────┘   │
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │  Teams webhook handler (:3978)       │   │
│  │  Receives Teams messages             │   │
│  │  Routes to Hermes via herdr CLI      │   │
│  │  Relays responses back to Teams      │   │
│  └──────────────────────────────────────┘   │
└───────────┬─────────────────────────────────┘
            │
    ┌───────┴───────┐
    │  Teams bot    │ ← @Hermes messages
    │  :3978/api    │
    └───────────────┘
```

**Key design decisions:**
- **Hermes runs as a herdr agent** — herdr tracks its lifecycle (`idle`/`working`/`done`/`blocked`), manages its pane, and provides the standard herdr API for prompting
- **Teams webhook handler** runs as a separate process — it bridges Teams messages to the herdr CLI without the complexity of the hermes gateway
- **Omp** runs as a herdr agent in the Workers workspace — spawns and manages worker agents on Hermes's request

## Quick Start

### 1. Register a Teams bot

Use the `teams` CLI (included in the image) to register the bot:

```bash
# Login to Azure AD
teams login

# Create the bot app (replace <your-domain> with your public URL)
teams app create \
  --name "Hermes" \
  --endpoint "https://<your-domain>/api/messages"
```

This outputs `CLIENT_ID`, `CLIENT_SECRET`, and `TENANT_ID`. Save them.

**For local dev:** use `devtunnel` for a public HTTPS URL:

```bash
devtunnel create hermes-bot --allow-anonymous
devtunnel port create hermes-bot --port 3978 --is-public
# Use the tunnel URL as the endpoint above
```

**Optional:** Restrict access to specific Teams users:

```bash
teams status --verbose  # shows your AAD object ID
```

### 2. Create `.env` file

```bash
cat > .env << 'EOF'
# Microsoft Teams bot credentials (from teams app create)
TEAMS_CLIENT_ID=<your-client-id>
TEAMS_CLIENT_SECRET=<your-client-secret>
TEAMS_TENANT_ID=<your-tenant-id>

# Restrict access to specific Teams users (optional but recommended)
# Get AAD object IDs from `teams status --verbose`
TEAMS_ALLOWED_USERS=12345678-1234-1234-1234-123456789012
EOF
```

### 3. Build and run

```bash
docker compose -f nervous-system/docker-compose.yml up -d --build
```

### 4. Verify

```bash
# Check all services are running
docker compose -f nervous-system/docker-compose.yml ps

# Check Hermes is tracked by herdr (lifecycle visible)
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent list

# Check Omp
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent list | grep omp

# Test direct herdr prompting (bypass Teams)
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent prompt hermes "Introduce yourself." --wait --timeout 300000

# Control Omp/workers
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent prompt omp "Review the PR changes." --wait --timeout 300000
```

### 5. Chat with Hermes via Teams

Open Microsoft Teams and message @Hermes in any chat or channel.

## Stopping

```bash
docker compose -f nervous-system/docker-compose.yml down
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TEAMS_CLIENT_ID` | Yes* | Azure AD app client ID |
| `TEAMS_CLIENT_SECRET` | Yes* | Azure AD app client secret |
| `TEAMS_TENANT_ID` | Yes* | Azure AD tenant ID |
| `TEAMS_PORT` | No | Webhook listener port (default: 3978) |
| `HERMES_MODEL_PROVIDER` | No | Model provider (default: `custom`) |
| `HERMES_MODEL_BASE_URL` | No | Model API endpoint (default: `http://llama:8080/v1`) |
| `HERMES_MODEL_DEFAULT` | No | Default model name |

\* Required for Teams integration. Without these, the webhook handler starts but Teams messages won't be processed.

### Model Provider

The nervous system uses llama.cpp for local model inference (via the `llama` service in docker-compose). To point to your own model:

```yaml
# In docker-compose.yml, llama service command:
command:
  - --model
  - /models/your-model.gguf
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image build — herdr + Node.js + bun + Hermes Agent + Omp + Teams CLI + webhook handler |
| `config.toml` | Herdr headless server config |
| `init.sh` | Startup script (server → workspaces → hermes agent + omp agent + webhook handler) |
| `docker-compose.yml` | Full stack: llama.cpp + nervous-system with Teams webhook |
| `teams_webhook_handler/` | Python webhook handler — bridges Teams ↔ herdr CLI |

## Persistence

Named volumes preserve state across restarts:

- `herdr-data` — herdr config, sessions, agent state
- `workspace` — shared workspace directory
- `models` — llama.cpp model files

## Troubleshooting

### Hermes not responding via Teams

1. Check the webhook handler logs:
   ```bash
   docker compose -f nervous-system/docker-compose.yml logs -f nervous-system | grep -i webhook
   ```

2. Verify Teams credentials:
   ```bash
   docker compose -f nervous-system/docker-compose.yml exec nervous-system \
     sh -c 'echo "CLIENT_ID set: $([ -n "$TEAMS_CLIENT_ID" ] && echo yes || echo no)"'
   ```

3. Test Hermes directly via herdr (bypass Teams):
   ```bash
   docker compose -f nervous-system/docker-compose.yml exec nervous-system \
     herdr agent prompt hermes "Say hello." --wait --timeout 300000
   ```

### Herdr doesn't see Hermes

Hermes should appear in `herdr agent list`. If not:
```bash
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr workspace list
docker compose -f nervous-system/docker-compose.yml exec nervous-system herdr agent list
```

### Webhook not receiving Teams messages

1. Verify the port is exposed: `docker port nervous-system 3978`
2. Check the endpoint URL registered with Teams matches `https://<domain>/api/messages`
3. For local dev, confirm the devtunnel is running and forwarding to port 3978
