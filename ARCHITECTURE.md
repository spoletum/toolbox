# Herdr Nervous System Architecture

## Overview

Herdr is the nervous system. Two harnesses operate on top of it:

| Component | Role | Harness | Skill |
|-----------|------|---------|-------|
| **Herdr** | Nervous system — workspace/pane/agent runtime, CLI, IPC | — | `herdr` (built-in) |
| **Hermes** | Brain — decision-making, orchestration, agent lifecycle control | `hermes` | `herdr` (can run `herdr` CLI in its pane) |
| **Omp** | Worker-spawner — creates and manages worker agents on Hermes's request | `omp` | herdr CLI (via pane) |

```
┌─────────────────────────────────────────────────────┐
│                     Herdr Server                     │
│  workspaces → tabs → panes → agents (IPC via sock)  │
└──────────┬──────────────────────────────────────────┘
           │
     ┌─────┴─────┐
     │ wX:NS     │  wW:Workers
     │  ┌───┐    │  ┌───┐
     │  │H  │    │  │O  │
     │  └───┘    │  └───┘
     │  Hermes   │  Omp
     └───────────┘  ┌──────┐
                    │Workers│ ← spawned by Omp on Hermes's command
                    └──────┘
```

## Hermes (Brain Harness)

**Workspace:** `wX` (Nervous System)  
**Pane:** `wX:p1`  
**CWD:** `/home/spoletum/Projects/codentient/magellan`

Hermes has the **herdr skill** — it runs inside a herdr-managed pane with `HERDR_ENV=1` and can invoke the `herdr` CLI:

```bash
# She can inspect the system
herdr workspace list
herdr agent list
herdr pane layout --pane wX:p1

# She can split panes (spawn workers)
herdr pane split --pane wX:p1 --direction right --cwd /tmp/work --no-focus

# She can read/write agents
herdr agent read wX:p2 --source detection --lines 50
herdr agent prompt wX:p2 "Do the thing." --wait --timeout 120000

# She can control Omp
herdr agent prompt omp "Spawn 3 reviewers for PR #42." --wait --timeout 300000
```

**Responsibilities:**
- Accept top-level tasks
- Decide which workers to spawn and what roles they fill
- Prompt Omp to create workers
- Monitor worker state (`idle`, `working`, `done`, `blocked`)
- Collect and synthesize results
- Clean up worker agents when work is complete

## Omp (Worker-Spawning Harness)

**Workspace:** `wW` (Workers)  
**Pane:** `wW:p1`  
**CWD:** `/home/spoletum/Projects/spoletum/toolbox`

Omp receives spawn requests from Hermes and creates worker agents:

```bash
# Omp receives a spawn request from Hermes
herdr agent prompt omp "Create 2 reviewer agents for the nvchad Dockerfile."

# Omp splits panes and starts workers
herdr agent start reviewer-1 --kind codex --pane wW:p2
herdr agent start reviewer-2 --kind codex --pane wW:p3

# Omp can also coordinate workers
herdr agent prompt reviewer-1 "Review auth changes." --wait --timeout 300000
herdr agent prompt reviewer-2 "Review infra changes." --wait --timeout 300000

# Omp reports back to Hermes when workers are done
herdr agent read wW:p2 --source detection --lines 100
herdr agent read wW:p3 --source detection --lines 100
```

**Responsibilities:**
- Create worker agents in dedicated panes
- Assign specific tasks to each worker
- Wait for worker completion
- Collect and consolidate outputs
- Report results back to Hermes

## Worker Agents

Workers are spawned as new herdr agents in panes within `wW` (Workers) or `wX` (Nervous System), depending on the workspace Omp was instructed to use.

**Lifecycle:**
```
spawn → idle → working → done/blocked → cleanup
```

**Naming:** `worker-<role>-<number>` or domain-specific (`reviewer-1`, `infra-reviewer`, etc.)

**Cleanup:** Hermes or Omp can target a worker's pane and replace/kill it when work is complete.

## Communication Protocol

### Hermes → Omp
Hermes prompts Omp's agent with a task description. Omp executes and reports back.

```
herdr agent prompt omp "<TASK>" --wait --timeout <SECONDS>
```

### Omp → Workers
Omp splits panes, starts agents, and prompts them.

```
herdr pane split --pane wW:p1 --direction right --cwd /tmp/work --no-focus
herdr agent start <NAME> --kind <KIND> --pane <NEW_PANE_ID>
herdr agent prompt <NAME> "<TASK>" --wait --timeout <SECONDS>
```

### Workers → Omp → Hermes
Workers output results to their panes. Omp reads them via `herdr agent read`, consolidates, and reports to Hermes.

```
herdr agent read <WORKER> --source detection --lines 200
```

## Workspace Layout

```
wX: Nervous System (Hermes)
├── t1
│   ├── p1: hermes (brain, idle/working)

wW: Workers (Omp + Workers)
├── t1
│   ├── p1: omp (worker-spawner, idle/working)
│   ├── p2: worker-1 (assigned task)
│   ├── p3: worker-2 (assigned task)
│   └── ...
```

## Startup Sequence

1. Herdr server starts (persistent, `default` session)
2. Hermes launches in `wX` with `HERDR_ENV=1`
3. Omp launches in `wW` with `HERDR_ENV=1`
4. Hermes and Omp are idle, awaiting prompts
5. External system or user prompts Hermes with a task
6. Hermes coordinates with Omp to spawn workers
7. Workers execute, report to Omp
8. Omp consolidates and reports to Hermes
9. Hermes delivers final result
