_ta_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="start attach pick p detach stop status list"
    local orch_dir="$HOME/dev/orchestrator"

    case $cword in
        1)  # Command completion
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)  # Project completion (for commands that need it)
            case "$prev" in
                start|attach|detach|stop|status)
                    local projects=$(ls "$orch_dir/projects/" 2>/dev/null | sed 's/.json//')
                    COMPREPLY=($(compgen -W "$projects" -- "$cur"))
                    ;;
            esac
            ;;
        3)  # Agent number completion
            local cmd="${words[1]}"
            local project="${words[2]}"
            case "$cmd" in
                start|attach|detach|stop)
                    local config="$orch_dir/projects/${project}.json"
                    if [[ -f "$config" ]]; then
                        local agents=$(jq -r '.agents[]' "$config" 2>/dev/null | sed 's/agent-//')
                        COMPREPLY=($(compgen -W "$agents" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
    esac
}

complete -F _ta_completions ta
