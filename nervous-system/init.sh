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

# ── Launch Hermes in Nervous System workspace ──────────────────────────────
echo "⚙️ Starting Hermes (brain harness)..."

# Split off a new pane from the root pane
NS_SPLIT=$(herdr pane split --pane "$NS_ROOT_PANE" --direction right --cwd /workspace --no-focus)
NS_HERMES_PANE=$(echo "$NS_SPLIT" | jqf "result.pane.pane_id")

herdr agent start hermes --kind hermes --pane "$NS_HERMES_PANE" --timeout 60000
echo "✓ Hermes started in $NS_HERMES_PANE"

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
echo "║  Server PID:  $HERDR_PID"
echo "║  Socket:      /root/.config/herdr/herdr.sock"
echo "║  Hermes:      $NS_HERMES_PANE (Nervous System workspace)"
echo "║  Omp:         $W_OMP_PANE (Workers workspace)"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Control with:"
echo "  herdr agent prompt hermes \"<TASK>\" --wait --timeout 300000"
echo "  herdr agent list"
echo "  herdr workspace list"

# ── Keep running ───────────────────────────────────────────────────────────
wait $HERDR_PID
