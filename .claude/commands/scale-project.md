---
description: Scale a project's agent count up or down
argument-hint: <project-name> <target-count>
allowed-tools: Read, Write, Bash(git:*), Bash(tmux:*), Bash(jq:*), Bash(mkdir:*), Bash(ls:*), Bash(cat:*), Bash(mv:*)
---

# Scale Project Agents

Change the number of agents for an existing project. Scaling down is blocked if any agents have unfinished work.

## Arguments

- `$ARGUMENTS` - Format: `<project-name> <target-count>`
  - `project-name` - Existing project name (e.g., `basil`)
  - `target-count` - Desired number of agents (minimum: 1)

## Example

```bash
/scale-project basil 5    # Scale basil from 3 to 5 agents
/scale-project homelab 1  # Scale homelab from 2 to 1 agent
```

## Step 1: Parse and Validate Arguments

```bash
ORCH_DIR="$HOME/dev/orchestrator"
NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
TARGET_COUNT=$(echo "$ARGUMENTS" | awk '{print $2}')

# Validate arguments
if [ -z "$NAME" ] || [ -z "$TARGET_COUNT" ]; then
    echo "ERROR: Usage: /scale-project <project-name> <target-count>"
    exit 1
fi

if ! [[ "$TARGET_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: target-count must be a positive integer (got: $TARGET_COUNT)"
    exit 1
fi

CONFIG_FILE="$ORCH_DIR/projects/${NAME}.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Project '$NAME' not found. Expected: $CONFIG_FILE"
    exit 1
fi

echo "Project: $NAME"
echo "Target agents: $TARGET_COUNT"
```

## Step 2: Load Current Config and Determine Action

```bash
CURRENT_COUNT=$(jq '.agents | length' "$CONFIG_FILE")
MAIN_BRANCH=$(jq -r '.mainBranch' "$CONFIG_FILE")
PROJECT_DIR="$ORCH_DIR/workspaces/$NAME"

echo "Current agents: $CURRENT_COUNT"
echo "Target agents: $TARGET_COUNT"

if [ "$TARGET_COUNT" -eq "$CURRENT_COUNT" ]; then
    echo ""
    echo "Already at $TARGET_COUNT agents. Nothing to do."
    exit 0
elif [ "$TARGET_COUNT" -gt "$CURRENT_COUNT" ]; then
    echo "Action: Scale UP (adding $(($TARGET_COUNT - $CURRENT_COUNT)) agent(s))"
else
    echo "Action: Scale DOWN (removing $(($CURRENT_COUNT - $TARGET_COUNT)) agent(s))"
fi
```

## Step 3 (Scale Up): Create New Agent Branches and Worktrees

If scaling UP, for each new agent from CURRENT_COUNT+1 to TARGET_COUNT:

```bash
if [ "$TARGET_COUNT" -gt "$CURRENT_COUNT" ]; then
    cd "$PROJECT_DIR/repo"
    git fetch origin

    for i in $(seq $(($CURRENT_COUNT + 1)) $TARGET_COUNT); do
        AGENT="agent-$i"
        BRANCH="agent-$i"

        echo ""
        echo "--- Creating $AGENT ---"

        # Create branch: check local, then remote, then create from main
        if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
            echo "Local branch '$BRANCH' already exists"
        elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
            echo "Branch exists on remote, creating local tracking branch"
            git branch "$BRANCH" "origin/$BRANCH"
        else
            echo "Creating new branch from $MAIN_BRANCH"
            git branch "$BRANCH" "$MAIN_BRANCH"
        fi

        # Create worktree
        git worktree add "../$AGENT" "$BRANCH"

        # Push branch to remote
        cd "../$AGENT"
        git push -u origin "$BRANCH" 2>/dev/null || echo "Branch may already exist on remote"
        cd "$PROJECT_DIR/repo"

        echo "$AGENT created."
    done
fi
```

## Step 4 (Scale Down): Check for Unfinished Work

If scaling DOWN, check ALL agents slated for removal before taking any action. Abort if any have unfinished work.

```bash
if [ "$TARGET_COUNT" -lt "$CURRENT_COUNT" ]; then
    ISSUES=()

    for i in $(seq $(($TARGET_COUNT + 1)) $CURRENT_COUNT); do
        AGENT="agent-$i"
        AGENT_DIR="$PROJECT_DIR/$AGENT"

        if [ ! -d "$AGENT_DIR" ]; then
            echo "WARNING: $AGENT_DIR does not exist, skipping checks"
            continue
        fi

        cd "$AGENT_DIR"

        # Check 1: On a feature branch? (not on agent branch = active work)
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [ "$CURRENT_BRANCH" != "$AGENT" ]; then
            ISSUES+=("$AGENT: on branch '$CURRENT_BRANCH' (active work in progress)")
        fi

        # Check 2: Uncommitted changes?
        DIRTY=$(git status --porcelain)
        if [ -n "$DIRTY" ]; then
            ISSUES+=("$AGENT: has uncommitted changes")
        fi

        # Check 3: Unpushed commits?
        UPSTREAM=$(git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "")
        if [ -n "$UPSTREAM" ]; then
            UNPUSHED=$(git log @{u}..HEAD --oneline 2>/dev/null)
            if [ -n "$UNPUSHED" ]; then
                ISSUES+=("$AGENT: has unpushed commits")
            fi
        fi
    done

    if [ ${#ISSUES[@]} -gt 0 ]; then
        echo ""
        echo "ERROR: Cannot scale down. The following agents have unfinished work:"
        echo ""
        for issue in "${ISSUES[@]}"; do
            echo "  - $issue"
        done
        echo ""
        echo "Resolve these issues first, then retry."
        exit 1
    fi
fi
```

## Step 5 (Scale Down): Stop Sessions and Remove Worktrees

Only reached if all dirty checks pass.

```bash
if [ "$TARGET_COUNT" -lt "$CURRENT_COUNT" ]; then
    for i in $(seq $(($TARGET_COUNT + 1)) $CURRENT_COUNT); do
        AGENT="agent-$i"
        SESSION="${NAME}-agent-${i}"

        echo ""
        echo "--- Removing $AGENT ---"

        # Stop tmux session if running
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            tmux kill-session -t "$SESSION"
            echo "Stopped tmux session: $SESSION"
        fi

        # Remove worktree (git refuses if dirty, additional safety net)
        cd "$PROJECT_DIR/repo"
        git worktree remove "../$AGENT"
        echo "Removed worktree: $AGENT"
        echo "Branch '$AGENT' preserved on local and remote."
    done
fi
```

## Step 6: Update Project Config

Rewrite the agents array to reflect the new count.

```bash
jq --argjson n "$TARGET_COUNT" '.agents = [range(1; $n+1) | "agent-\(.)"]' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo ""
echo "Updated config: $CONFIG_FILE"
```

## Step 7: Verify Setup

```bash
cd "$PROJECT_DIR/repo"
git worktree list
echo ""
cat "$CONFIG_FILE"
```

## Output

```markdown
# Scale Complete: {name}

| | Before | After |
|---|---|---|
| Agent count | {old} | {new} |

## Notes

- Agent branches are preserved on remote (never deleted)
- Config updated: ~/dev/orchestrator/projects/{name}.json
- Start new agents with: ./tools/tmux-agents.sh start {name} {N}
```
