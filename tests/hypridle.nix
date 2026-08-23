{
    hypridle,
    hypridleConfig,
    hypridleService,
    hyprlandRoot,
    pkgs,
}:
let
    hyprctl = pkgs.lib.getExe' pkgs.hyprland "hyprctl";
    dpmsDisable = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
    dpmsEnable = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
    target = "graphical-session.target";
    expectedSettings = {
        general.ignore_dbus_inhibit = false;
        listener = [
            {
                timeout = 600;
                on-timeout = dpmsDisable;
                on-resume = dpmsEnable;
            }
        ];
    };
in
assert hypridle.enable;
assert hypridle.settings == expectedSettings;
assert hypridle.systemdTarget == target;
assert hypridleService.Install.WantedBy == [ target ];
assert hypridleService.Unit.After == [ target ];
assert hypridleService.Unit.PartOf == [ target ];
assert hypridleService.Unit.ConditionEnvironment == "WAYLAND_DISPLAY";
assert hypridleService.Service.ExecStart == [ "${pkgs.lib.getExe hypridle.package}" ];
pkgs.runCommandLocal "hypridle-idle-policy-check"
    {
        config = hypridleConfig;
        inherit
            dpmsDisable
            dpmsEnable
            hyprlandRoot
            ;
    }
    ''
        set -eu

        require_line() {
            file=$1
            line=$2
            if ! grep -Fqx -- "$line" "$file"; then
                printf 'missing line in %s: %s\n' "$file" "$line" >&2
                exit 1
            fi
        }

        test "$(grep -Fxc 'listener {' "$config")" -eq 1
        require_line "$config" 'general {'
        require_line "$config" '  ignore_dbus_inhibit=false'
        require_line "$config" 'listener {'
        require_line "$config" "  on-resume=$dpmsEnable"
        require_line "$config" "  on-timeout=$dpmsDisable"
        require_line "$config" '  timeout=600'

        if grep -Eiq 'suspend|hibernate|systemctl[[:space:]].*sleep' "$config"; then
            echo 'hypridle config contains an automatic sleep action' >&2
            exit 1
        fi
        if grep -Fiq 'hypridle' "$hyprlandRoot"; then
            echo 'Hyprland launches a duplicate hypridle process' >&2
            exit 1
        fi

        touch "$out"
    ''
