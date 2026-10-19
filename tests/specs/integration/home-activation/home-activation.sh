#!/usr/bin/env bash
# Home Manager activation entries and its run helper require Bash.
set -euo pipefail

if [[ ${1-} == --entry ]]; then
    # shellcheck disable=SC1090
    source "$2"
    entry=$(< "$3")
    entry=${entry//"$4"/"$HOME"}
    cd "$HOME"
    eval "$entry"
    exit
fi

: "${testRunner:?}" "${hmInit:?}" "${fixtureHome:?}" "${piEntry:?}" "${piEmptyEntry:?}"
: "${rtkEntry:?}" "${rtkExecutable:?}" "${starshipEntry:?}" "${starshipConfig:?}" "${out:?}"

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
runner=$testRunner

new_home() {
    export HOME="$root/$1"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_RUNTIME_DIR="$HOME/runtime"
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
}

execute_entry() {
    local script=$1 mode=${2-live}
    local -a dry_run=()
    if [[ $mode == dry ]]; then
        dry_run=(DRY_RUN=1)
    fi
    env -i HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        PATH="$PATH" TERM=dumb LC_ALL=C "${dry_run[@]}" \
        bash "$runner" --entry "$hmInit" "$script" "$fixtureHome"
}

new_home pi-fresh
execute_entry "$piEntry"
settings="$HOME/.pi/agent/settings.json"
pidev="$HOME/.pi/agent/pidev.json"
jq -e '
    .theme == "tokyo-night" and .enableInstallTelemetry == false
    and .compaction.enabled == true
    and .compaction.reserveTokens == 16384
    and .packages == ["git:github.com/mineugene/pi-dev-config"]
' "$settings"
jq -e '. == {declared: {keep: "new"}}' "$pidev"
for file in "$settings" "$pidev"; do
    test ! -L "$file"
    test -w "$file"
    test "$(stat -c %a "$file")" = 600
    cp "$file" "$file.expected"
done
settings_inode=$(stat -c %i "$settings")
pidev_inode=$(stat -c %i "$pidev")
execute_entry "$piEntry"
cmp "$settings" "$settings.expected"
cmp "$pidev" "$pidev.expected"
test "$(stat -c %i "$settings")" = "$settings_inode"
test "$(stat -c %i "$pidev")" = "$pidev_inode"

new_home pi-existing
mkdir -p "$HOME/.pi/agent"
settings="$HOME/.pi/agent/settings.json"
pidev="$HOME/.pi/agent/pidev.json"
printf '%s\n' '{"theme":"user-theme","model":"user-model","compaction":{"enabled":false},"packages":["unrelated",{"source":"git:github.com/mineugene/pi-dev-config","local":true}]}' > "$settings"
printf '%s\n' '{"declared":{"keep":"old","stale":true},"undeclared":{"user":true}}' > "$pidev"
execute_entry "$piEntry"
jq -e '
    .theme == "user-theme" and .model == "user-model"
    and .compaction == {enabled: false}
    and .packages == ["unrelated", {source: "git:github.com/mineugene/pi-dev-config", local: true}]
' "$settings"
jq -e '. == {declared: {keep: "new"}, undeclared: {user: true}}' "$pidev"
cp "$pidev" "$pidev.expected"
execute_entry "$piEmptyEntry"
cmp "$pidev" "$pidev.expected"
printf '%s\n' '{"packages":"not-an-array"}' > "$settings"
execute_entry "$piEntry"
jq -e '.packages == ["git:github.com/mineugene/pi-dev-config"]' "$settings"
printf '%s\n' '{"packages":["unrelated"]}' > "$settings"
execute_entry "$piEntry"
jq -e '.packages == ["unrelated", "git:github.com/mineugene/pi-dev-config"]' "$settings"

for malformed in 'not json' '[]' 'null'; do
    for file in settings pidev; do
        new_home "pi-malformed-$file-${#malformed}"
        mkdir -p "$HOME/.pi/agent"
        target="$HOME/.pi/agent/$file.json"
        printf '%s\n' "$malformed" > "$target"
        cp "$target" "$root/expected"
        if execute_entry "$piEntry" > "$root/refused.log" 2>&1; then
            printf 'Pi activation accepted malformed %s\n' "$file" >&2
            exit 1
        fi
        grep -F 'Refusing to replace malformed' "$root/refused.log"
        cmp "$target" "$root/expected"
        test "$(find "$HOME/.pi/agent" -name '.*.??????' | wc -l)" -eq 0
    done
done

new_home pi-dry
execute_entry "$piEntry" dry
test ! -e "$HOME/.pi"
new_home pi-existing-dry
mkdir -p "$HOME/.pi/agent"
printf '%s\n' '{"theme":"user-theme"}' > "$HOME/.pi/agent/settings.json"
cp "$HOME/.pi/agent/settings.json" "$root/expected"
execute_entry "$piEntry" dry
cmp "$HOME/.pi/agent/settings.json" "$root/expected"
test ! -e "$HOME/.pi/agent/pidev.json"

new_home rtk-dry
execute_entry "$rtkEntry" dry
test ! -e "$XDG_CONFIG_HOME/rtk"
new_home rtk-live
execute_entry "$rtkEntry"
test -s "$XDG_CONFIG_HOME/rtk/config.toml"
env -i HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" "$rtkExecutable" telemetry status > "$root/rtk-status"
grep -Eq '^  enabled: +no$' "$root/rtk-status"
execute_entry "$rtkEntry"

new_home starship-live
mkdir -p "$XDG_CONFIG_HOME/starship"
config="$XDG_CONFIG_HOME/starship/config.toml"
ln -s "$starshipConfig" "$config"
execute_entry "$starshipEntry"
test ! -L "$config"
cmp "$config" "$starshipConfig"
execute_entry "$starshipEntry"
cmp "$config" "$starshipConfig"
cp "$starshipConfig" "$root/next-starship.toml"
chmod u+w "$root/next-starship.toml"
printf '\n# synthetic next generation\n' >> "$root/next-starship.toml"
rm "$config"
ln -s "$root/next-starship.toml" "$config"
execute_entry "$starshipEntry"
test ! -L "$config"
cmp "$config" "$root/next-starship.toml"
test ! -e "$config.tmp"

new_home starship-dry
mkdir -p "$XDG_CONFIG_HOME/starship"
config="$XDG_CONFIG_HOME/starship/config.toml"
ln -s "$starshipConfig" "$config"
execute_entry "$starshipEntry" dry
if [[ ! -L $config ]]; then
    printf 'Starship activation replaced its symlink during DRY_RUN\n' >&2
    exit 1
fi
cmp "$config" "$starshipConfig"
test ! -e "$config.tmp"

touch "$out"
