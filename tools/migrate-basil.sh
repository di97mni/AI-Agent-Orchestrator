#!/usr/bin/env bash
# Migrate existing basil worktrees to orchestrator structure
# Run this from ~/dev/orchestrator (NOT from inside any worktree)
set -euo pipefail

ORCH_DIR="$HOME/dev/orchestrator"
BASIL_DIR="$ORCH_DIR/workspaces/basil"

echo "=== Basil Migration Script ==="
echo ""

# Check we're not inside a worktree
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == *"/dev/basil"* ]]; then
    echo "ERROR: Run this script from ~/dev/orchestrator, not from inside a worktree"
    exit 1
fi

# Check source directories exist
for dir in basil basil-agent-1 basil-agent-2 basil-agent-3; do
    if [[ ! -d "$HOME/dev/$dir" ]]; then
        echo "ERROR: $HOME/dev/$dir not found"
        exit 1
    fi
done

echo "Step 1: Recording current worktree state..."
cd "$HOME/dev/basil"
git worktree list > /tmp/worktrees-before.txt
cat /tmp/worktrees-before.txt
echo ""

echo "Step 2: Moving directories..."
mkdir -p "$BASIL_DIR"
mv "$HOME/dev/basil" "$BASIL_DIR/repo"
mv "$HOME/dev/basil-agent-1" "$BASIL_DIR/agent-1"
mv "$HOME/dev/basil-agent-2" "$BASIL_DIR/agent-2"
mv "$HOME/dev/basil-agent-3" "$BASIL_DIR/agent-3"
echo "Moved all directories to $BASIL_DIR/"
echo ""

echo "Step 3: Repairing worktree references..."
cd "$BASIL_DIR/repo"
git worktree repair
echo ""

echo "Step 4: Verifying new state..."
git worktree list
echo ""

echo "=== Migration Complete ==="
echo ""
echo "New locations:"
echo "  Main repo:  $BASIL_DIR/repo"
echo "  Agent 1:    $BASIL_DIR/agent-1"
echo "  Agent 2:    $BASIL_DIR/agent-2"
echo "  Agent 3:    $BASIL_DIR/agent-3"
echo ""
echo "Next steps:"
echo "  1. cd ~/dev/orchestrator"
echo "  2. ./tools/tmux-agents.sh start basil 1"
