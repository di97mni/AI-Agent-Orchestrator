# Agent Orchestrator

Manage multiple AI coding agents across projects with centralized session management and coordination.

## Architecture

```
orchestrator/
├── .claude/commands/       ← Orchestrator commands (/setup-project)
├── projects/               ← Project configurations (git-ignored, machine-specific)
├── status/                 ← Per-project status directories (git-ignored)
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

### 2. Reconnect to a Session

```bash
# Interactive session picker
./tools/tmux-agents.sh pick    # or: ta p

# Or attach directly
./tools/tmux-agents.sh attach basil 1
```

## Commands

### Orchestrator Commands (run from ~/dev/orchestrator)

| Command | Description |
|---------|-------------|
| `/setup-project <name> <url>` | Add new project with worktrees |

Agent commands (e.g. `/plan-task`, `/run-task`, `/finish-task`) are project-specific and defined in each workspace's `.claude/commands/`.

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

# Interactive session picker
./tools/tmux-agents.sh pick             # or: ta p

# View status
./tools/tmux-agents.sh status           # All projects
./tools/tmux-agents.sh status basil     # Single project

# List all tmux sessions
./tools/tmux-agents.sh list
```

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

## Backup & Portability

- Project configs, status dirs, and workspaces are git-ignored (machine-specific)
- Recreate with `/setup-project`

## Requirements

- tmux
- jq (for JSON parsing)
- gh (GitHub CLI)
- Claude Code
