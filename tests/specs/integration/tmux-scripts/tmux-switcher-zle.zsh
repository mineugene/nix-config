fpath=("$TEST_FUNCTIONS" $fpath)
autoload -Uz tmux-session-switcher
zle -N tmux-session-switcher
bindkey -e

tmux() {
    if [[ $1 == attach-session ]]; then
        if zle; then print active; else print inactive; fi > "$TEST_ATTACH_CONTEXT"
    fi
    command tmux "$@"
}

bindkey '^[t' tmux-session-switcher
record-pending() {
    print -r -- "$BUFFER" > "$TEST_PENDING"
}
zle -N record-pending
bindkey '^Xr' record-pending
: > "$TEST_READY"
