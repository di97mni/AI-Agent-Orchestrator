---
description: Show Kanban board view of agent tasks
argument-hint: [project]
allowed-tools: Read, Bash(cat:*), Bash(ls:*), Bash(gh:*), Bash(jq:*), Bash(git:*), Glob
---

# Agent Board (Kanban View)

Display a Kanban-style board showing task status across agents.

## Arguments

- `$ARGUMENTS` - Optional project name (e.g., `basil`). If omitted, shows all projects.

## Step 1: Gather Data

Same as `/status` command - load projects and gather agent info.

## Step 2: Format as Kanban Board

```markdown
# Agent Board - {project} - {timestamp}

## Idle
| Agent | Last Activity |
|-------|---------------|
| agent-2 | Finished task 91 (2 days ago) |

## In Progress
| Agent | Task | Subtask | Progress |
|-------|------|---------|----------|
| agent-1 | 90: Room Availability | 90.4: Command handler | ████████░░ 3/5 |
| agent-3 | 104: Secret Scanning | 104.5: Integration | █████████░ 4/5 |

## In Review
| Agent | Task | PR | Status |
|-------|------|----|--------|
| (none) | | | |

## Blocked
| Agent | Task | Blocker | Since |
|-------|------|---------|-------|
| (none) | | | |

---

## Task Queue (Unassigned)
```bash
gh issue list --label "task:planned" --assignee "" --json number,title
```

| Issue | Task | Ready Since |
|-------|------|-------------|
| #220 | Task 95: Guest Profiles | 2 days ago |
| #221 | Task 96: Rate Management | 1 day ago |
```

## Progress Bar Helper

```
0%   ░░░░░░░░░░
20%  ██░░░░░░░░
40%  ████░░░░░░
60%  ██████░░░░
80%  ████████░░
100% ██████████
```

Calculate: `done_subtasks / total_subtasks * 10` blocks filled.
