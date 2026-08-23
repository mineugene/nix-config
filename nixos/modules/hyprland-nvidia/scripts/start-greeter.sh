#!/bin/sh
set -u

# ReGreet scans this directory first, selecting the UWSM session that skips
# its boot-target wait when it starts the logged-in Hyprland desktop.
export XDG_DATA_DIRS="/etc/greetd/sessions${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

if [ "${GREETER_DBUS_SESSION:-0}" != 1 ]; then
    export GREETER_DBUS_SESSION=1
    exec dbus-run-session -- "$0" "$@"
fi

runtime_dir=${XDG_RUNTIME_DIR:?greetd must provide XDG_RUNTIME_DIR}
wayfire_template=${GREETER_WAYFIRE_TEMPLATE:-/etc/greetd/wayfire.ini}
wayfire_config="$runtime_dir/wayfire.ini"
session_status="$runtime_dir/greeter-session-status"
rm -f "$session_status"
cat "$wayfire_template" > "$wayfire_config"

# Wayfire implements real output mirroring in its output backend. Derive the
# stable Wayland connector names from connected DRM connectors; the first one
# renders the greeter and every other connected output mirrors it.
source_output=
drm_dir=${GREETER_DRM_DIR:-/sys/class/drm}
for status_file in "$drm_dir"/card*-*/status; do
    [ -r "$status_file" ] || continue
    [ "$(cat "$status_file")" = connected ] || continue

    connector=${status_file%/status}
    connector=${connector##*/}
    output=$(printf '%s\n' "$connector" | awk '{ sub(/^card[0-9]+-/, ""); print }')

    if [ -z "$source_output" ]; then
        source_output=$output
        printf '\n[output:%s]\nmode = auto\nposition = 0,0\n' "$output" >> "$wayfire_config"
    else
        printf '\n[output:%s]\nmode = mirror %s\n' "$output" "$source_output" >> "$wayfire_config"
    fi
done

if [ -z "$source_output" ]; then
    printf '%s\n' 'greeter: no connected DRM output found; using Wayfire defaults' >&2
fi

export GREETER_SESSION_STATUS_FILE="$session_status"
wayfire --config "$wayfire_config" >/dev/null &
wayfire_pid=$!

while [ ! -f "$session_status" ]; do
    if ! kill -0 "$wayfire_pid" 2>/dev/null; then
        wait "$wayfire_pid"
        exit $?
    fi
    sleep 0.1
done

IFS= read -r status < "$session_status"
case $status in
    "" | *[!0-9]*) status=1 ;;
esac

# Wayfire handles SIGTERM by running its compositor shutdown sequence.
kill -TERM "$wayfire_pid" 2>/dev/null || :
wait "$wayfire_pid" || :
exit "$status"
