---
description: Setup a new project with worktrees for agents
argument-hint: <name> <repo-url> [num-agents]
allowed-tools: Read, Write, Bash(git:*), Bash(mkdir:*), Bash(ls:*), Bash(cat:*)
---

# Setup New Project

Clone a repository and create agent worktrees for parallel development.

## Arguments

- `$ARGUMENTS` - Format: `<name> <repo-url> [num-agents]`
  - `name` - Project name (e.g., `myproject`)
  - `repo-url` - Git repository URL
  - `num-agents` - Optional. Number of agents (default: 3)

## Example

```bash
/setup-project myproject git@github.com:org/myproject.git 3
```

## Step 1: Parse Arguments

```bash
ORCH_DIR="$HOME/dev/orchestrator"
NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
REPO_URL=$(echo "$ARGUMENTS" | awk '{print $2}')
NUM_AGENTS=$(echo "$ARGUMENTS" | awk '{print $3}')
NUM_AGENTS=${NUM_AGENTS:-3}

echo "Project: $NAME"
echo "Repo: $REPO_URL"
echo "Agents: $NUM_AGENTS"
```

## Step 2: Create Directory Structure

```bash
PROJECT_DIR="$ORCH_DIR/workspaces/$NAME"
mkdir -p "$PROJECT_DIR"
mkdir -p "$ORCH_DIR/status/$NAME"
```

## Step 3: Clone Repository

```bash
cd "$PROJECT_DIR"
git clone "$REPO_URL" repo
cd repo
```

## Step 4: Create Agent Branches and Worktrees

For each agent (1 to NUM_AGENTS):

```bash
for i in $(seq 1 $NUM_AGENTS); do
    AGENT="agent-$i"
    BRANCH="agent-$i"

    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git branch "$BRANCH"
    fi

    # Create worktree
    git worktree add "../$AGENT" "$BRANCH"

    # Push branch to remote
    cd "../$AGENT"
    git push -u origin "$BRANCH" 2>/dev/null || echo "Branch may already exist on remote"
    cd "$PROJECT_DIR/repo"
done
```

## Step 5: Create Project Config

Write to `projects/{name}.json`:

```json
{
  "name": "{name}",
  "repo": "{repo-url}",
  "path": "workspaces/{name}",
  "mainBranch": "master",
  "agents": ["agent-1", "agent-2", ...]
}
```

## Step 6: Create Status Directory Placeholder

```bash
touch "$ORCH_DIR/status/$NAME/.gitkeep"
```

## Step 7: Verify Setup

```bash
cd "$PROJECT_DIR/repo"
git worktree list
```

## Output

```markdown
# Project Setup Complete: {name}

| Component | Location |
|-----------|----------|
| Main repo | ~/dev/orchestrator/workspaces/{name}/repo |
| Agent 1 | ~/dev/orchestrator/workspaces/{name}/agent-1 |
| Agent 2 | ~/dev/orchestrator/workspaces/{name}/agent-2 |
| Agent 3 | ~/dev/orchestrator/workspaces/{name}/agent-3 |
| Config | ~/dev/orchestrator/projects/{name}.json |
| Status | ~/dev/orchestrator/status/{name}/ |

## Next Steps

1. Start an agent session:
   ```bash
   ./tools/tmux-agents.sh start {name} 1
   ```

2. View status:
   ```bash
   /status {name}
   ```
```

## Notes

- Agent branches (`agent-1`, `agent-2`, etc.) are persistent and never deleted
- Configure GitHub to NOT auto-delete agent branches after PR merge
- Each agent creates feature branches for tasks: `task-{id}-{title}`
