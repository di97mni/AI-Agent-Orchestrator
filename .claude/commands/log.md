---
description: Show agent activity log
argument-hint: <project> [agent] [--last N]
allowed-tools: Read, Bash(cat:*), Bash(ls:*), Bash(tail:*), Bash(head:*), Bash(grep:*), Glob
---

# Agent Activity Log

Display the activity log for agents in a project.

## Arguments

- `$ARGUMENTS` - Format: `<project> [agent] [--last N]`
  - `project` - Required. Project name (e.g., `basil`)
  - `agent` - Optional. Specific agent (e.g., `agent-1`). If omitted, shows all agents.
  - `--last N` - Optional. Show only last N entries per agent (default: 10)

## Examples

```bash
/log basil                    # All agents, last 10 entries each
/log basil agent-1            # Only agent-1
/log basil --last 20          # All agents, last 20 entries each
/log basil agent-1 --last 5   # Agent-1, last 5 entries
```

## Step 1: Parse Arguments

```bash
ORCH_DIR="$HOME/dev/orchestrator"
PROJECT=""
AGENT=""
LAST_N=10

# Parse $ARGUMENTS
for arg in $ARGUMENTS; do
    if [[ "$arg" == "--last" ]]; then
        # Next arg is the number
        continue
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        LAST_N=$arg
    elif [[ "$arg" == agent-* ]]; then
        AGENT=$arg
    else
        PROJECT=$arg
    fi
done
```

## Step 2: Read Log Files

```bash
STATUS_DIR="$ORCH_DIR/status/$PROJECT"

if [[ -n "$AGENT" ]]; then
    # Single agent
    LOG_FILES=("$STATUS_DIR/$AGENT.log.md")
else
    # All agents
    LOG_FILES=($STATUS_DIR/agent-*.log.md)
fi
```

## Step 3: Display Log Entries

For each log file:

```bash
if [[ -f "$LOG_FILE" ]]; then
    echo "## $(basename $LOG_FILE .log.md)"
    echo ""
    # Show last N entries (entries start with "## " timestamp)
    # Use awk or grep to extract entries
    cat "$LOG_FILE"
fi
```

## Output Format

```markdown
# Activity Log - basil

## agent-1

### 2026-01-07T14:32:15Z | SUBTASK_COMPLETE
- **Task**: 90 - Room Availability
- **Subtask**: 90.3 (3/5)
- **Action**: Added 12 API tests for reservation validation
- **Branch**: task-90-room-availability
- **Commit**: abc1234

### 2026-01-07T14:28:00Z | SUBTASK_START
- **Task**: 90 - Room Availability
- **Subtask**: 90.3
- **Progress**: 2/5

---

## agent-2

### 2026-01-07T14:15:00Z | SUBTASK_COMPLETE
...
```

## If No Logs Exist

> No activity logs found for {project}.
>
> Logs are created when agents run commands like `/claim-task`, `/implement-task`, etc.
> Each command automatically appends to `~/dev/orchestrator/status/{project}/{agent}.log.md`
