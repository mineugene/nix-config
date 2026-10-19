#!/bin/sh
set -eu
: "${schema:?}" "${config:?}" "${package:?}" "${uiCheck:?}" "${out:?}"

# The style is substituted by replaceVars, so building it here turns an unused
# token into a check failure instead of a broken system build.
: "${style:?}"
if grep -n '@[a-zA-Z][a-zA-Z]*@' "$style"; then
    printf 'swaync style.css left an unsubstituted token\n' >&2
    exit 1
fi

# The Vulkan GSK renderer paints swaync's layer-shell surfaces opaque black on
# this driver stack, hiding every window under them; the service must pin the
# OpenGL renderer.
case " ${serviceEnvironment:-} " in
    *" GSK_RENDERER=ngl "*) ;;
    *)
        printf 'swaync.service must set GSK_RENDERER=ngl, got: %s\n' "$serviceEnvironment" >&2
        exit 1
        ;;
esac

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
