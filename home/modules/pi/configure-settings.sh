#!/bin/sh
set -eu

settings_dir=$1
package_source=$2
settings_path=$settings_dir/settings.json
pidev_path=$settings_dir/pidev.json

merge_json() (
    path=$1
    label=$2
    shift 2

    if [ ! -e "$path" ]; then
        printf '{}\n' > "$path"
    fi
    if ! jq -e 'type == "object"' "$path" >/dev/null; then
        printf 'Refusing to replace malformed %s: %s\n' "$label" "$path" >&2
        exit 1
    fi

    tmp=$(mktemp --tmpdir="$settings_dir" ".${path##*/}.XXXXXX")
    trap 'rm -f "$tmp"' 0
    trap 'exit 1' HUP INT TERM
    jq "$@" "$path" > "$tmp"
    chmod 0600 "$tmp"
    if ! cmp -s "$tmp" "$path"; then
        mv -f "$tmp" "$path"
    fi
)

if [ "${DRY_RUN+x}" = x ]; then
    printf 'Would merge pi-dev-config defaults into %s\n' "$settings_path"
    printf 'Would apply declared pi-dev-config settings to %s\n' "$pidev_path"
    exit 0
fi

mkdir -p "$settings_dir"
merge_json "$settings_path" 'pi settings' \
    --arg package "$package_source" \
    --argjson defaults "$PI_SETTINGS_DEFAULTS" \
    --from-file "$PI_SETTINGS_FILTER"
merge_json "$pidev_path" 'pi-dev-config settings' \
    --argjson declared "$PI_DECLARED_SETTINGS" \
    --from-file "$PI_DECLARED_FILTER"
