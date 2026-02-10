#!/usr/bin/env bash
# Project-aware multi-agent tmux session manager
# Usage: ./tmux-agents.sh <command> <project> [agent]
set -euo pipefail

ORCH_DIR="$HOME/dev/orchestrator"

usage() {
    cat << EOF
Usage: $(basename "$0") <command> <project> [agent]

Commands:
  start <project> [agent]   Start agent(s). With agent: start AND attach. Without: start all detached.
  attach <project> <agent>  Attach to existing session (for reconnecting)
  pick, p                   Interactive session picker - select from all configured sessions
  detach <project> <agent>  Detach session from another terminal
  stop <project> [agent]    Stop agent(s)
  status [project]          Show session status
  list                      List all sessions

Examples:
  $(basename "$0") start basil 1        # Start agent-1 and attach (most common)
  $(basename "$0") start basil          # Start all agents (detached)
  $(basename "$0") attach basil 2       # Reconnect to agent-2
  $(basename "$0") pick                 # Interactive picker for all sessions (alias: p)
  $(basename "$0") stop basil           # Stop all basil agents
  $(basename "$0") status               # Show all sessions
  $(basename "$0") status basil         # Show basil sessions only
EOF
}

get_project_config() {
    local project=$1
    local config_file="$ORCH_DIR/projects/${project}.json"
    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Project '$project' not found. Config: $config_file" >&2
        exit 1
    fi
    cat "$config_file"
}

get_agents() {
    local project=$1
    get_project_config "$project" | jq -r '.agents[]' | sed 's/agent-//'
}

get_workspace_path() {
    local project=$1
    local agent=$2
    echo "$ORCH_DIR/workspaces/$project/agent-$agent"
}

session_name() {
    local project=$1
    local agent=$2
    echo "${project}-agent-${agent}"
}

start_agent() {
    local project=$1
    local agent=$2
    local attach=${3:-false}
    local session=$(session_name "$project" "$agent")
    local dir=$(get_workspace_path "$project" "$agent")

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Workspace not found: $dir"
        echo "Run migration or /setup-project first."
        exit 1
    fi

    if tmux has-session -t "$session" 2>/dev/null; then
        echo "Session $session already exists"
        if [[ "$attach" == "true" ]]; then
            tmux attach -t "$session"
        fi
    else
        if [[ "$attach" == "true" ]]; then
            # Start and attach
            tmux new-session -s "$session" -c "$dir"
        else
            # Start detached
            tmux new-session -d -s "$session" -c "$dir"
            echo "Started session $session (detached)"
        fi
    fi
}

stop_agent() {
    local project=$1
    local agent=$2
    local session=$(session_name "$project" "$agent")

    if tmux has-session -t "$session" 2>/dev/null; then
        tmux kill-session -t "$session"
        echo "Stopped session $session"
    else
        echo "Session $session not running"
    fi
}

attach_agent() {
    local project=$1
    local agent=$2
    local session=$(session_name "$project" "$agent")

    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
    else
        echo "Session $session not running. Use 'start $project $agent' first."
        exit 1
    fi
}

detach_agent() {
    local project=$1
    local agent=$2
    local session=$(session_name "$project" "$agent")

    if tmux has-session -t "$session" 2>/dev/null; then
        tmux detach-client -s "$session"
        echo "Detached from $session (session still running)"
    else
        echo "Session $session not running"
    fi
}

show_status() {
    local filter_project=${1:-}

    echo "# Agent Sessions"
    echo ""

    # Get all projects or filtered
    if [[ -n "$filter_project" ]]; then
        projects=("$filter_project")
    else
        projects=($(ls "$ORCH_DIR/projects/" 2>/dev/null | sed 's/.json//' || true))
    fi

    for project in "${projects[@]}"; do
        echo "## $project"
        echo ""
        echo "| Agent | Session | Status | Directory |"
        echo "|-------|---------|--------|-----------|"

        for agent in $(get_agents "$project"); do
            local session=$(session_name "$project" "$agent")
            local dir=$(get_workspace_path "$project" "$agent")

            if tmux has-session -t "$session" 2>/dev/null; then
                status="RUNNING"
            else
                status="stopped"
            fi

            if [[ -d "$dir" ]]; then
                dir_status="✓"
            else
                dir_status="✗ (not found)"
            fi

            echo "| agent-$agent | $session | $status | $dir_status |"
        done
        echo ""
    done
}

list_sessions() {
    echo "# All tmux sessions"
    echo ""
    tmux ls 2>/dev/null || echo "No sessions running"
}

pick_session() {
    # Build list from project configs (shows all sessions, not just running)
    local -a entries
    for config in "$ORCH_DIR/projects/"*.json; do
        local project
        project=$(jq -r '.name' "$config")
        for agent in $(jq -r '.agents[]' "$config" | sed 's/agent-//'); do
            local session
            session=$(session_name "$project" "$agent")
            if tmux has-session -t "$session" 2>/dev/null; then
                entries+=("$session (RUNNING)")
            else
                entries+=("$session (stopped)")
            fi
        done
    done

    if [[ ${#entries[@]} -eq 0 ]]; then
        echo "No agent sessions configured."
        exit 1
    fi

    # Use fzf if available, otherwise use select
    if command -v fzf &>/dev/null; then
        local selected
        selected=$(printf '%s\n' "${entries[@]}" | fzf --height=40% --reverse --prompt="Select session: ")
        if [[ -n "$selected" ]]; then
            # Extract session name (strip status suffix)
            local session_name_selected="${selected%% (*}"
            if [[ "$selected" == *"(RUNNING)"* ]]; then
                tmux attach -t "$session_name_selected"
            else
                # Parse project and agent number from session name
                local proj="${session_name_selected%-agent-*}"
                local agent_num="${session_name_selected##*-agent-}"
                start_agent "$proj" "$agent_num" true
            fi
        fi
    else
        echo "Select a session:"
        echo ""
        select entry in "${entries[@]}" "Cancel"; do
            if [[ "$entry" == "Cancel" ]]; then
                echo "Cancelled."
                exit 0
            elif [[ -n "$entry" ]]; then
                local session_name_selected="${entry%% (*}"
                if [[ "$entry" == *"(RUNNING)"* ]]; then
                    tmux attach -t "$session_name_selected"
                else
                    local proj="${session_name_selected%-agent-*}"
                    local agent_num="${session_name_selected##*-agent-}"
                    start_agent "$proj" "$agent_num" true
                fi
                break
            else
                echo "Invalid selection. Try again."
            fi
        done
    fi
}

# Main
case "${1:-}" in
    start)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 start <project> [agent]"; exit 1; }
        project=$2
        if [[ -n "${3:-}" ]]; then
            # Single agent: start AND attach
            start_agent "$project" "$3" true
        else
            # All agents: start detached
            for agent in $(get_agents "$project"); do
                start_agent "$project" "$agent" false
            done
            echo ""
            echo "All agents started. Attach with: $0 attach $project <agent>"
        fi
        ;;
    attach)
        [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: $0 attach <project> <agent>"; exit 1; }
        attach_agent "$2" "$3"
        ;;
    pick|p)
        pick_session
        ;;
    detach)
        [[ -z "${2:-}" || -z "${3:-}" ]] && { echo "Usage: $0 detach <project> <agent>"; exit 1; }
        detach_agent "$2" "$3"
        ;;
    stop)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 stop <project> [agent]"; exit 1; }
        project=$2
        if [[ -n "${3:-}" ]]; then
            stop_agent "$project" "$3"
        else
            for agent in $(get_agents "$project"); do
                stop_agent "$project" "$agent"
            done
        fi
        ;;
    status)
        show_status "${2:-}"
        ;;
    list)
        list_sessions
        ;;
    *)
        usage
        ;;
esac
