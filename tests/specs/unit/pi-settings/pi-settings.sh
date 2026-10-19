#!/bin/sh
set -eu

configure=$1
export PI_SETTINGS_FILTER="$2" PI_DECLARED_FILTER="$3"
export PI_SETTINGS_DEFAULTS='{"theme":"tokyo-night","quietStartup":true}'
export PI_DECLARED_SETTINGS='{"tools":{"enabled":true}}'
root=$(mktemp -d)
trap 'rm -rf "$root"' 0
trap 'exit 1' HUP INT TERM
package=git:github.com/mineugene/pi-dev-config

DRY_RUN='' sh "$configure" "$root/dry" "$package"
test ! -e "$root/dry"
sh "$configure" "$root/agent" "$package"
jq -e --arg package "$package" '.theme == "tokyo-night" and .packages == [$package]' "$root/agent/settings.json"
jq -e '.tools == {enabled: true}' "$root/agent/pidev.json"
test "$(stat -c %a "$root/agent/settings.json")" = 600
inode=$(stat -c %i "$root/agent/settings.json")
sh "$configure" "$root/agent" "$package"
test "$(stat -c %i "$root/agent/settings.json")" = "$inode"

jq --arg package "$package" '.theme = "custom" | .packages = [{source: $package}, "other"]' \
    "$root/agent/settings.json" > "$root/settings"
mv "$root/settings" "$root/agent/settings.json"
printf '%s\n' '{"tools":{"enabled":false,"removed":true},"undeclared":42}' > "$root/agent/pidev.json"
sh "$configure" "$root/agent" "$package"
jq -e --arg package "$package" '.theme == "custom" and .packages == [{source: $package}, "other"]' "$root/agent/settings.json"
jq -e '.tools == {enabled: true} and .undeclared == 42' "$root/agent/pidev.json"

for invalid in '[]' 'not-json'; do
    printf '%s\n' "$invalid" > "$root/agent/settings.json"
    if sh "$configure" "$root/agent" "$package"; then
        printf '%s\n' 'accepted malformed settings' >&2
        exit 1
    fi
    test "$(cat "$root/agent/settings.json")" = "$invalid"
done
test -z "$(find "$root/agent" -name '.*.??????' -print)"
