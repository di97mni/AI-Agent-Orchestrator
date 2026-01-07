---
description: Show status of all agents across projects
argument-hint: [project]
allowed-tools: Read, Bash(cat:*), Bash(ls:*), Bash(gh:*), Bash(jq:*), Bash(git:*), Glob
---

# Agent Status

Display the current status of all agents, optionally filtered by project.

## Arguments

- `$ARGUMENTS` - Optional project name (e.g., `basil`). If omitted, shows all projects.

## Step 1: Load Projects

```bash
ORCH_DIR="$HOME/dev/orchestrator"

if [[ -n "$ARGUMENTS" ]]; then
    PROJECTS="$ARGUMENTS"
else
    PROJECTS=$(ls "$ORCH_DIR/projects/" 2>/dev/null | sed 's/.json//' | tr '\n' ' ')
fi
echo "Projects: $PROJECTS"
```

## Step 2: For Each Project

For each PROJECT in the list:

### 2a. Load config
```bash
cat "$ORCH_DIR/projects/${PROJECT}.json"
```

### 2b. Check each agent

For each agent in the project's `agents` array:

1. **Check if worktree exists and get branch**:
   ```bash
   AGENT_DIR="$ORCH_DIR/workspaces/${PROJECT}/${AGENT}"
   if [[ -d "$AGENT_DIR" ]]; then
       cd "$AGENT_DIR" && git branch --show-current
   fi
   ```

2. **Read last log entry**:
   ```bash
   LOG_FILE="$ORCH_DIR/status/${PROJECT}/${AGENT}.log.md"
   if [[ -f "$LOG_FILE" ]]; then
       # Get last ## header (most recent entry)
       grep "^## " "$LOG_FILE" | tail -1
   fi
   ```

3. **Get GitHub issue if on feature branch**:
   ```bash
   cd "$AGENT_DIR"
   BRANCH=$(git branch --show-current)
   if [[ "$BRANCH" == task-* ]]; then
       gh issue list --assignee @me --state open --json number,title --jq '.[0] | "Issue #\(.number): \(.title)"' 2>/dev/null
   fi
   ```

## Step 3: Format Output

Display as a markdown table:

```markdown
# Agent Status - {current_timestamp}

## {project}

| Agent | Branch | Task | Last Event | Time |
|-------|--------|------|------------|------|
| agent-1 | task-90-room | 90: Room Availability | SUBTASK_COMPLETE | 5m ago |
| agent-2 | agent-2 | (idle) | - | - |
| agent-3 | task-104-secret | 104: Secret Scanning | PR_CREATED | 1h ago |

### Recent Activity
{last 5 log entries across all agents, sorted by time}
```

## Determine Status

| Branch Pattern | Last Event | Status |
|----------------|------------|--------|
| `agent-*` | any | idle |
| `task-*` | SUBTASK_START | implementing |
| `task-*` | SUBTASK_COMPLETE | implementing |
| `task-*` | DEVTEST_START | devtest |
| `task-*` | DEVTEST_COMPLETE | ready-for-pr |
| `task-*` | PR_CREATED | pr-open |
| `task-*` | BLOCKED | blocked |
