# Agent Orchestrator

Manage multiple AI coding agents across projects with centralized status tracking and coordination.

## Architecture

```
orchestrator/
├── .claude/commands/       ← Orchestrator commands (/status, /board, /log)
├── projects/               ← Project configurations (tracked)
├── status/                 ← Agent activity logs (tracked for backup)
├── workspaces/             ← Git-ignored (project worktrees live here)
│   └── {project}/
│       ├── repo/           ← Main clone (for worktrees + local tests)
│       ├── agent-1/        ← Worktree
│       ├── agent-2/        ← Worktree
│       └── agent-3/        ← Worktree
├── tools/
│   └── tmux-agents.sh      ← Project-aware session manager
└── README.md
```

## Quick Start

### 1. Start Agent Session

```bash
cd ~/dev/orchestrator

# Start agent and attach (most common)
./tools/tmux-agents.sh start basil 1

# Or start all agents (detached)
./tools/tmux-agents.sh start basil
```

### 2. Check Status (from orchestrator)

```bash
cd ~/dev/orchestrator
claude

> /status basil
```

### 3. View Activity Log

```bash
> /log basil agent-1
```

## Commands

### Orchestrator Commands (run from ~/dev/orchestrator)

| Command | Description |
|---------|-------------|
| `/status [project]` | Show all agents status |
| `/board [project]` | Kanban view of tasks |
| `/log <project> [agent]` | Show activity log |
| `/setup-project <name> <url>` | Add new project |

### Agent Commands (run from agent worktree)

| Command | Description |
|---------|-------------|
| `/checkin <event> "<msg>"` | Log activity (usually auto-called) |
| `/claim-task <id>` | Claim task → auto-checkin TASK_CLAIMED |
| `/implement-task <id>` | Implement subtask → auto-checkin SUBTASK_START/COMPLETE |
| `/devtest` | Pre-PR review → auto-checkin DEVTEST_* |
| `/finish-task <id>` | Cleanup → auto-checkin TASK_COMPLETE |

## tmux Session Management

```bash
# Start single agent + attach (most common workflow)
./tools/tmux-agents.sh start basil 1

# Start all agents (background)
./tools/tmux-agents.sh start basil

# Reconnect after disconnect
./tools/tmux-agents.sh attach basil 1

# Detach (from another terminal)
./tools/tmux-agents.sh detach basil 1

# Stop agents
./tools/tmux-agents.sh stop basil 1    # Single
./tools/tmux-agents.sh stop basil       # All

# View status
./tools/tmux-agents.sh status           # All projects
./tools/tmux-agents.sh status basil     # Single project
```

## Activity Log Format

Logs are append-only markdown files in `status/{project}/{agent}.log.md`:

```markdown
## 2026-01-07T14:32:15Z | SUBTASK_COMPLETE
- **Agent**: agent-1
- **Branch**: task-90-room-availability
- **Task**: 90
- **Action**: Added 12 API tests for reservation validation
- **Commit**: abc1234

## 2026-01-07T14:28:00Z | SUBTASK_START
- **Agent**: agent-1
- **Branch**: task-90-room-availability
- **Task**: 90
- **Action**: Starting subtask 90.3
- **Commit**: def5678
```

## Event Types

| Event | Trigger | Description |
|-------|---------|-------------|
| `TASK_CLAIMED` | /claim-task | Agent claimed a task |
| `SUBTASK_START` | /implement-task | Starting a subtask |
| `SUBTASK_COMPLETE` | /implement-task | Finished a subtask |
| `BLOCKED` | /checkin | Hit a blocker |
| `DEVTEST_START` | /devtest | Starting pre-PR review |
| `DEVTEST_COMPLETE` | /devtest | Finished review |
| `PR_CREATED` | manual | Created pull request |
| `TASK_COMPLETE` | /finish-task | All done, cleaned up |
| `NOTE` | /checkin | General note |

## Adding a New Project

### Option 1: Using /setup-project

```bash
cd ~/dev/orchestrator
claude
> /setup-project myproject git@github.com:org/myproject.git 3
```

### Option 2: Manual Setup

```bash
# Clone and create worktrees
mkdir -p workspaces/myproject
cd workspaces/myproject
git clone git@github.com:org/myproject.git repo
cd repo
git worktree add ../agent-1 -b agent-1
git worktree add ../agent-2 -b agent-2
git worktree add ../agent-3 -b agent-3

# Push agent branches
for i in 1 2 3; do
    cd ../agent-$i && git push -u origin agent-$i
done

# Create config
cat > ~/dev/orchestrator/projects/myproject.json << 'EOF'
{
  "name": "myproject",
  "repo": "git@github.com:org/myproject.git",
  "path": "workspaces/myproject",
  "mainBranch": "master",
  "agents": ["agent-1", "agent-2", "agent-3"]
}
EOF

# Create status directory
mkdir -p ~/dev/orchestrator/status/myproject
```

## Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (~/dev/orchestrator)                                          │
│                                                                              │
│  Human runs:                                                                 │
│  - /status basil         → See all agents                                   │
│  - /board basil          → Kanban view                                      │
│  - /log basil agent-1    → Activity history                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ reads status/
                                    ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Agent 1        │ │  Agent 2        │ │  Agent 3        │
│  workspaces/    │ │  workspaces/    │ │  workspaces/    │
│  basil/agent-1  │ │  basil/agent-2  │ │  basil/agent-3  │
│                 │ │                 │ │                 │
│  /claim-task    │ │  /claim-task    │ │  /claim-task    │
│  /implement-task│ │  /implement-task│ │  /implement-task│
│  /devtest       │ │  /devtest       │ │  /devtest       │
│       │         │ │       │         │ │       │         │
│       ▼         │ │       ▼         │ │       ▼         │
│  /checkin ──────┼─┼───────┼─────────┼─┼───────┼─────────┤
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             ▼
                    status/{project}/{agent}.log.md
                    (committed to orchestrator repo)
```

## Backup & Portability

- **Status logs are committed** to the orchestrator repo
- Clone orchestrator on a new machine to see full history
- Workspaces are git-ignored (recreate with /setup-project)

## Requirements

- tmux
- jq (for JSON parsing)
- gh (GitHub CLI)
- Claude Code
