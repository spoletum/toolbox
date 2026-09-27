#!/bin/bash
set -euo pipefail

export HOME=/root
export PATH="/root/.bun/bin:/usr/local/bin:${PATH}"

# ── Start herdr server (headless) ──────────────────────────────────────────
echo "⚙️ Starting herdr server..."
herdr server &
HERDR_PID=$!

# Wait for server socket to appear
for i in $(seq 1 30); do
    if [ -S /root/.config/herdr/herdr.sock ]; then
        echo "✓ herdr server ready (PID $HERDR_PID)"
        break
    fi
    sleep 1
done

# Verify server is responding
if ! herdr workspace list > /dev/null 2>&1; then
    echo "✗ herdr server failed to start"
    exit 1
fi

# ── Helper: extract JSON field with python3 ─────────────────────────────────
jqf() {
    python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = '$1'.split('.')
val = data
for k in keys:
    if isinstance(val, dict):
        val = val[k]
    elif isinstance(val, (list, tuple)) and k.isdigit():
        val = val[int(k)]
    else:
        sys.exit(1)
print(val)
"
}

# ── Create Nervous System workspace ────────────────────────────────────────
echo "⚙️ Creating Nervous System workspace..."
NS_CREATE=$(herdr workspace create --label "Nervous System")
NS_WS_ID=$(echo "$NS_CREATE" | jqf "result.workspace.workspace_id")
NS_ROOT_PANE=$(echo "$NS_CREATE" | jqf "result.root_pane.pane_id")
echo "  Nervous System: ws=$NS_WS_ID root_pane=$NS_ROOT_PANE"

# ── Create Workers workspace ───────────────────────────────────────────────
echo "⚙️ Creating Workers workspace..."
W_CREATE=$(herdr workspace create --label "Workers")
W_WS_ID=$(echo "$W_CREATE" | jqf "result.workspace.workspace_id")
W_ROOT_PANE=$(echo "$W_CREATE" | jqf "result.root_pane.pane_id")
echo "  Workers: ws=$W_WS_ID root_pane=$W_ROOT_PANE"

# ── Launch Hermes via Teams Gateway ──────────────────────────────────────
echo "⚙️ Starting Hermes Teams gateway..."

# Start the hermes gateway in background (handles Teams webhook on :3978)
# --accept-hooks: auto-approve shell hooks without TTY prompt
hermes gateway run --accept-hooks &
HERMES_GATEWAY_PID=$!
echo "✓ Hermes Teams gateway started (PID $HERMES_GATEWAY_PID)"
echo "  Webhook: http://localhost:3978/api/messages"

# ── Launch Omp in Workers workspace ───────────────────────────────────────
echo "⚙️ Starting Omp (worker-spawner)..."

# Focus the Workers workspace, then split off a new pane
herdr workspace focus "$W_WS_ID"
W_SPLIT=$(herdr pane split --pane "$W_ROOT_PANE" --direction right --cwd /workspace --no-focus)
W_OMP_PANE=$(echo "$W_SPLIT" | jqf "result.pane.pane_id")

herdr agent start omp --kind omp --pane "$W_OMP_PANE" --timeout 60000
echo "✓ Omp started in $W_OMP_PANE"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Herdr Nervous System Ready                              ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Herdr Server PID:    $HERDR_PID"
echo "║  Herdr Socket:        /root/.config/herdr/herdr.sock"
echo "║  Hermes Gateway PID:  $HERMES_GATEWAY_PID"
echo "║  Teams Webhook:       http://localhost:3978/api/messages"
echo "║  Omp Agent:           $W_OMP_PANE (Workers workspace)"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Control via herdr (for Omp/workers):"
echo "  herdr agent prompt omp \"<TASK>\" --wait --timeout 300000"
echo "  herdr agent list"
echo ""
echo "Control via Teams:"
echo "  Message @Hermes in any Teams chat/channel"

# ── Keep running ───────────────────────────────────────────────────────────
wait $HERDR_PID $HERMES_GATEWAY_PID
