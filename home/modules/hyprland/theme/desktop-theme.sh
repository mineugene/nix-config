#!/bin/sh
set -u

state_home=${XDG_STATE_HOME:-${HOME:?HOME must be set}/.local/state}
state_dir="$state_home/mineugene-desktop"
state_file="$state_dir/theme"

read_mode() {
    if [ -f "$state_file" ]; then
        IFS= read -r mode < "$state_file"
    else
        mode=$DESKTOP_THEME_DEFAULT_MODE
    fi

    case $mode in
        dark | light) printf '%s\n' "$mode" ;;
        *)
            printf 'desktop-theme: invalid state: %s\n' "$mode" >&2
            return 1
            ;;
    esac
}

apply_mode() {
    case $1 in
        dark)
            color_scheme=prefer-dark
            gtk_theme=Adwaita-dark
            ;;
        light)
            color_scheme=prefer-light
            gtk_theme=Adwaita
            ;;
    esac

    gsettings --schemadir "$DESKTOP_THEME_GSETTINGS_SCHEMA_DIR" \
        set org.gnome.desktop.interface color-scheme "$color_scheme"
    gsettings --schemadir "$DESKTOP_THEME_GSETTINGS_SCHEMA_DIR" \
        set org.gnome.desktop.interface gtk-theme "$gtk_theme"
}

write_mode() {
    mkdir -p -- "$state_dir"
    tmp=$(mktemp "$state_dir/.theme.XXXXXX")
    trap 'rm -f -- "$tmp"' 0
    printf '%s\n' "$1" > "$tmp"
    mv -- "$tmp" "$state_file"
    trap - 0
}

usage() {
    printf '%s\n' "$1" >&2
    exit 2
}

case ${1-} in
    get)
        [ "$#" -eq 1 ] || usage 'usage: desktop-theme get'
        read_mode
        ;;
    set)
        [ "$#" -eq 2 ] || usage 'usage: desktop-theme set dark|light'
        case $2 in
            dark | light) ;;
            *) usage 'usage: desktop-theme set dark|light' ;;
        esac
        write_mode "$2"
        apply_mode "$2"
        ;;
    toggle)
        [ "$#" -eq 1 ] || usage 'usage: desktop-theme toggle'
        current_mode=$(read_mode)
        if [ "$current_mode" = dark ]; then
            next_mode=light
        else
            next_mode=dark
        fi
        write_mode "$next_mode"
        apply_mode "$next_mode"
        ;;
    apply)
        [ "$#" -eq 1 ] || usage 'usage: desktop-theme apply'
        apply_mode "$(read_mode)"
        ;;
    *) usage 'usage: desktop-theme get | set dark|light | toggle | apply' ;;
esac
