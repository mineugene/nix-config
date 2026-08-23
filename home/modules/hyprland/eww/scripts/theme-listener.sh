state_home=${XDG_STATE_HOME:-${HOME:?HOME must be set}/.local/state}
state_dir="$state_home/mineugene-desktop"

emit() {
    desktop-theme get 2>/dev/null || true
}

mkdir -p -- "$state_dir"
emit

while true; do
    while IFS= read -r changed_file; do
        if [[ $changed_file == theme ]]; then
            emit
        fi
    done < <(
        inotifywait \
            --monitor \
            --quiet \
            --event close_write,create,moved_to \
            --format '%f' \
            "$state_dir" 2>/dev/null || true
    )

    sleep 2
done
