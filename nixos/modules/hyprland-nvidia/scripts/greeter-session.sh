#!/bin/sh
set -u

status=1

# shellcheck disable=SC2329 # Invoked by the traps below.
cleanup() {
    trap - 0 1 2 15
    eww --config /etc/greetd/eww kill >/dev/null 2>&1 || :

    if [ -n "${GREETER_SESSION_STATUS_FILE:-}" ]; then
        status_file=$GREETER_SESSION_STATUS_FILE
        status_file_tmp=$status_file.$$
        if ! printf '%s\n' "$status" > "$status_file_tmp"; then
            printf 'greeter: failed to write session status to %s\n' "$status_file_tmp" >&2
            rm -f "$status_file_tmp"
            return
        fi
        if ! mv "$status_file_tmp" "$status_file"; then
            printf 'greeter: failed to publish session status to %s\n' "$status_file" >&2
            rm -f "$status_file_tmp"
        fi
    fi
}

trap cleanup 0
trap 'status=129; exit "$status"' 1
trap 'status=130; exit "$status"' 2
trap 'status=143; exit "$status"' 15

# greetd's home is /var/empty. Keep Eww's cache and log in the writable,
# session-scoped runtime directory instead.
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_CACHE_HOME="$XDG_RUNTIME_DIR"
fi

# Open an Eww instance on every output. Wayfire renders secondary outputs as
# mirrors of the source output, so the greeter remains identical everywhere.
outputs=$(wlr-randr | awk '/^[^[:space:]]/ { print $1 }')

if ! eww --config /etc/greetd/eww daemon >/dev/null 2>&1; then
    printf '%s\n' 'greeter: failed to start eww daemon' >&2
fi

monitor=0
for _ in $outputs; do
    if ! eww --config /etc/greetd/eww open bar --id "bar-$monitor" --screen "$monitor"; then
        printf 'greeter: failed to open eww bar on monitor %s\n' "$monitor" >&2
    fi
    if ! eww --config /etc/greetd/eww open motd --id "motd-$monitor" --screen "$monitor"; then
        printf 'greeter: failed to open eww motd on monitor %s\n' "$monitor" >&2
    fi
    monitor=$((monitor + 1))
done

regreet
status=$?
printf 'greeter: regreet exited with status %s\n' "$status" >&2
exit "$status"
