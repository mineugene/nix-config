state_home=${XDG_STATE_HOME:-${HOME:?HOME must be set}/.local/state}
state_dir="$state_home/mineugene-desktop"
state_file="$state_dir/theme"
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
swaync_theme_dir="$config_home/swaync"
swaync_theme_file="$swaync_theme_dir/theme.css"

read_mode() {
    if [[ -f "$state_file" ]]; then
        IFS= read -r mode < "$state_file"
    else
        mode=$DESKTOP_THEME_DEFAULT_MODE
    fi

    case "$mode" in
        dark|light) printf '%s\n' "$mode" ;;
        *)
            printf 'desktop-theme: invalid state: %s\n' "$mode" >&2
            return 1
            ;;
    esac
}

apply_mode() {
    case "$1" in
        dark)
            color_scheme=prefer-dark
            gtk_theme=Adwaita-dark
            swaync_theme=$DESKTOP_THEME_SWAYNC_DARK_THEME
            ;;
        light)
            color_scheme=prefer-light
            gtk_theme=Adwaita
            swaync_theme=$DESKTOP_THEME_SWAYNC_LIGHT_THEME
            ;;
    esac

    gsettings --schemadir "$DESKTOP_THEME_GSETTINGS_SCHEMA_DIR" \
        set org.gnome.desktop.interface color-scheme "$color_scheme"
    gsettings --schemadir "$DESKTOP_THEME_GSETTINGS_SCHEMA_DIR" \
        set org.gnome.desktop.interface gtk-theme "$gtk_theme"

    mkdir -p -- "$swaync_theme_dir"
    tmp=$(mktemp "$swaync_theme_dir/.theme.css.XXXXXX")
    trap 'rm -f -- "$tmp"' EXIT
    install -m 0600 -- "$swaync_theme" "$tmp"
    mv -- "$tmp" "$swaync_theme_file"
    trap - EXIT

    timeout --kill-after=1s 1s \
        "$DESKTOP_THEME_SWAYNC_CLIENT" --skip-wait --reload-css >/dev/null 2>&1 || true
}

write_mode() {
    mkdir -p -- "$state_dir"
    tmp=$(mktemp "$state_dir/.theme.XXXXXX")
    trap 'rm -f -- "$tmp"' EXIT
    printf '%s\n' "$1" > "$tmp"
    mv -- "$tmp" "$state_file"
    trap - EXIT
}

case "${1-}" in
    get)
        if (( $# != 1 )); then
            printf 'usage: desktop-theme get\n' >&2
            exit 2
        fi
        read_mode
        ;;
    set)
        if (( $# != 2 )) || [[ $2 != dark && $2 != light ]]; then
            printf 'usage: desktop-theme set dark|light\n' >&2
            exit 2
        fi
        write_mode "$2"
        apply_mode "$2"
        ;;
    toggle)
        if (( $# != 1 )); then
            printf 'usage: desktop-theme toggle\n' >&2
            exit 2
        fi
        current_mode=$(read_mode)
        if [[ $current_mode == dark ]]; then
            next_mode=light
        else
            next_mode=dark
        fi
        write_mode "$next_mode"
        apply_mode "$next_mode"
        ;;
    apply)
        if (( $# != 1 )); then
            printf 'usage: desktop-theme apply\n' >&2
            exit 2
        fi
        apply_mode "$(read_mode)"
        ;;
    *)
        printf 'usage: desktop-theme get | set dark|light | toggle | apply\n' >&2
        exit 2
        ;;
esac
