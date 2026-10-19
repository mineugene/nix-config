#!/bin/sh

scan_active() {
    [ -e "$1/scanning" ]
}

scan_begin() {
    mkdir -p "$1"
    : > "$1/scanning"
}

scan_end() {
    rm -f "$1/scanning"
}

scan_watch() {
    scan_last=
    scan_was_active=false
    while :; do
        if scan_active "$1"; then
            scan_is_active=true
        else
            scan_is_active=false
        fi
        if [ "$scan_is_active" = true ] || [ "$scan_was_active" = true ]; then
            scan_current=$("$2")
            if [ "$scan_current" != "$scan_last" ]; then
                printf '%s\n' "$scan_current"
                scan_last=$scan_current
            fi
        fi
        scan_was_active=$scan_is_active
        sleep 1
    done
}
