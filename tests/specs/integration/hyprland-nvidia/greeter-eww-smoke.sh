#!/bin/sh
set -eu

config_dir=$1
log=$2
: "${waitHelpers:?}"
# shellcheck source=/dev/null
. "$waitHelpers"

eww --config "$config_dir" daemon --no-daemonize >"$log" 2>&1 &
daemon_pid=$!

cleanup() {
    eww --config "$config_dir" kill >/dev/null 2>&1 || true
    kill "$daemon_pid" >/dev/null 2>&1 || true
    wait "$daemon_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

eww_ready() {
    if ! kill -0 "$daemon_pid" 2>/dev/null; then
        wait "$daemon_pid" || true
        cat "$log" >&2
        exit 1
    fi
    timeout 2 eww --config "$config_dir" ping >/dev/null 2>&1
}
wait_until eww_ready
eww --no-daemonize --config "$config_dir" open bar --id bar-0 --screen 0 >/dev/null
eww --no-daemonize --config "$config_dir" open motd --id motd-0 --screen 0 >/dev/null
eww --config "$config_dir" debug >/dev/null
eww --config "$config_dir" kill >/dev/null
wait "$daemon_pid" || true
trap - EXIT HUP INT TERM
