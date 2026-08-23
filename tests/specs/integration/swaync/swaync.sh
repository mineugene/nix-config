#!/bin/sh
set -eu
: "${schema:?}" "${config:?}" "${package:?}" "${uiCheck:?}" "${out:?}"

check-jsonschema --schemafile "$schema" "$config"
resource=/org/erikreider/swaync/ui/notification.ui
for executable in "$package"/bin/* "$package"/bin/.*; do
    [ -f "$executable" ] || continue
    if gresource extract "$executable" "$resource" > notification.ui 2>/dev/null && [ -s notification.ui ]; then
        python3 "$uiCheck" notification.ui
        touch "$out"
        exit 0
    fi
done

printf 'no SwayNC executable embeds %s\n' "$resource" >&2
exit 1
