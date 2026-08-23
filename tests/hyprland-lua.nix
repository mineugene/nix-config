{
    pkgs,
    configuredMonitor,
    hyprland,
    hyprlandFiles,
    hyprlock,
    hyprlockFile,
    pointerCursor,
}:
let
    bindings = hyprlandFiles."hypr/bindings.lua".source;
    generatedMonitor = hyprlandFiles."hypr/generated/monitor.lua".source;
    generatedPrograms = hyprlandFiles."hypr/generated/programs.lua".source;
    monitors = hyprlandFiles."hypr/monitors.lua".source;
    root = hyprlandFiles."hypr/hyprland.lua".source;
in
assert hyprland.configType == "lua";
assert !hyprland.systemd.enable;
assert !hyprland.xwayland.enable;
assert !(hyprlandFiles ? "hypr/startup.lua");
assert hyprlock.enable;
assert pointerCursor.enable;
assert pointerCursor.package.pname == "capitaine-cursors";
assert pointerCursor.name == "capitaine-cursors-white";
assert pointerCursor.size == 24;
assert pointerCursor.gtk.enable;
pkgs.runCommandLocal "hyprland-lua-check"
    {
        inherit
            bindings
            configuredMonitor
            generatedMonitor
            generatedPrograms
            hyprlockFile
            monitors
            root
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

        reject_text() {
            file=$1
            text=$2
            if grep -Fq -- "$text" "$file"; then
                printf 'unexpected text in %s: %s\n' "$file" "$text" >&2
                exit 1
            fi
        }

        # Home Manager loads behavioral modules, but helpers load only when
        # explicitly required by those modules.
        require_line "$root" 'require("bindings")'
        require_line "$root" 'require("monitors")'
        reject_text "$root" 'require("startup")'
        reject_text "$root" 'require("generated.programs")'
        reject_text "$root" 'hl.bind('

        require_line "$bindings" 'local programs = require("generated.programs")'
        require_line "$monitors" 'local monitor = require("generated.monitor")'
        require_line "$monitors" 'local programs = require("generated.programs")'
        require_line "$monitors" 'if type(monitor) == "table" then'
        require_line "$monitors" '  hl.monitor(monitor)'
        require_line "$generatedMonitor" 'return nil'

        cat > "$TMPDIR/monitor-events.lua" <<'LUA'
        local callbacks = {}
        local executed = {}

        package.preload["generated.monitor"] = function()
          return nil
        end
        package.preload["generated.programs"] = function()
          return { monitor_topology = "/test/bin/monitor-topology" }
        end
        hl = {
          monitor = function() end,
          on = function(event, callback)
            callbacks[event] = callback
          end,
          exec_cmd = function(command)
            table.insert(executed, command)
          end,
        }

        dofile(os.getenv("MONITORS_LUA"))
        assert(type(callbacks["config.reloaded"]) == "function")
        assert(type(callbacks["monitor.added"]) == "function")
        assert(type(callbacks["config.props_refreshed"]) == "function")
        callbacks["config.reloaded"]()
        callbacks["monitor.added"]()
        callbacks["config.props_refreshed"]()
        assert(executed[1] == "/test/bin/monitor-topology apply")
        assert(executed[2] == "/test/bin/monitor-topology apply")
        assert(executed[3] == "/test/bin/monitor-topology focus-primary")
        LUA
        MONITORS_LUA="$monitors" ${pkgs.lua}/bin/lua "$TMPDIR/monitor-events.lua"

        # Lua's require returns true when a module returns nil. Exercise the
        # generated default monitor through Hyprland's parser so that value
        # cannot be passed to hl.monitor.
        config="$TMPDIR/config"
        runtime="$TMPDIR/runtime"
        mkdir -m 700 -p "$config/hypr/generated" "$runtime"
        ln -s "$bindings" "$config/hypr/bindings.lua"
        ln -s "$monitors" "$config/hypr/monitors.lua"
        ln -s "$generatedMonitor" "$config/hypr/generated/monitor.lua"
        ln -s "$generatedPrograms" "$config/hypr/generated/programs.lua"
        XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$runtime" ${pkgs.hyprland}/bin/Hyprland --verify-config --config "$root"
        require_line "$configuredMonitor" '  output = "DP-1",'
        require_line "$configuredMonitor" '  mode = "3840x2160@119.88",'
        require_line "$configuredMonitor" '  scale = 1.0,'
        require_line "$configuredMonitor" '  bitdepth = 10,'
        require_line "$configuredMonitor" '  cm = "auto",'
        ln -sfn "$configuredMonitor" "$config/hypr/generated/monitor.lua"
        XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="$runtime" ${pkgs.hyprland}/bin/Hyprland --verify-config --config "$root"

        # The lock handler is an opaque, OLED-safe Hyprlock surface using the
        # same shared Tokyo Night tokens as the desktop.
        require_line "$hyprlockFile" '  hide_cursor=true'
        require_line "$hyprlockFile" '  immediate_render=true'
        require_line "$hyprlockFile" '  color=rgb(000000)'
        require_line "$hyprlockFile" '  inner_color=rgb(16161e)'
        require_line "$hyprlockFile" '  outer_color=rgb(7aa2f7)'
        require_line "$hyprlockFile" '  font_color=rgb(c0caf5)'
        require_line "$hyprlockFile" '  font_family=IosevkaNF'
        require_line "$hyprlockFile" '  size=320, 52'

        # Fixed bindings preserve the user-facing key map.
        while IFS= read -r key; do
            grep -Fq -- "hl.bind(\"$key\"" "$bindings" || {
                printf 'missing binding: %s\n' "$key" >&2
                exit 1
            }
        done <<'KEYS'
        SUPER + RETURN
        SUPER + B
        SUPER + D
        SUPER + Q
        SUPER + F
        SUPER + L
        SUPER + T
        SUPER + M
        SUPER + V
        Print
        SUPER + left
        SUPER + down
        SUPER + up
        SUPER + right
        SUPER + SHIFT + left
        SUPER + SHIFT + down
        SUPER + SHIFT + up
        SUPER + SHIFT + right
        XF86AudioRaiseVolume
        XF86AudioLowerVolume
        XF86AudioMute
        XF86AudioMicMute
        SUPER + mouse:272
        SUPER + mouse:273
        KEYS

        require_line "$bindings" 'for workspace = 1, 9 do'
        require_line "$bindings" '    hl.bind("SUPER + " .. workspace, hl.dsp.focus({ workspace = workspace }))'
        require_line "$bindings" '    hl.bind("SUPER + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }))'

        require_line "$bindings" 'hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(programs.terminal))'
        require_line "$bindings" 'hl.bind("SUPER + B", hl.dsp.exec_cmd(programs.browser))'
        require_line "$bindings" 'hl.bind("SUPER + D", hl.dsp.exec_cmd(programs.ui_launcher))'
        require_line "$bindings" 'hl.bind("SUPER + L", hl.dsp.exec_cmd(programs.lock))'
        require_line "$bindings" 'hl.bind("SUPER + M", hl.dsp.exec_cmd(programs.ui_power))'
        require_line "$bindings" 'hl.bind("SUPER + V", hl.dsp.exec_cmd(programs.ui_clipboard))'
        require_line "$bindings" 'hl.bind("SUPER + Q", hl.dsp.window.close())'
        reject_text "$bindings" ' -show drun'
        reject_text "$bindings" 'cliphist'
        reject_text "$bindings" 'rofi'
        reject_text "$bindings" 'uwsm'
        require_line "$bindings" 'hl.bind("SUPER + F", hl.dsp.window.fullscreen())'
        require_line "$bindings" 'hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))'
        require_line "$bindings" 'hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))'
        require_line "$bindings" 'hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))'
        require_line "$bindings" '    locked = true,'
        require_line "$bindings" '    repeating = true,'
        require_line "$bindings" 'hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })'
        require_line "$bindings" 'hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })'

        # Motion stays fast: springs move physical windows, while opacity and
        # workspace transitions use quick easing to avoid visible bounce.
        require_line "$root" 'hl.curve("swift", {'
        require_line "$root" '  ["dampening"] = 50,'
        require_line "$root" '  ["mass"] = 1,'
        require_line "$root" '  ["stiffness"] = 600,'
        require_line "$root" '  ["type"] = "spring"'
        require_line "$root" 'hl.animation({'
        require_line "$root" '  ["leaf"] = "windows",'
        require_line "$root" '  ["speed"] = 2.5,'
        require_line "$root" '  ["spring"] = "swift"'
        require_line "$root" '  ["leaf"] = "windowsIn",'
        require_line "$root" '  ["speed"] = 2.2,'
        require_line "$root" '  ["style"] = "popin 96%"'
        require_line "$root" '  ["leaf"] = "windowsOut",'
        require_line "$root" '  ["speed"] = 1.4,'
        require_line "$root" '  ["leaf"] = "workspaces",'
        require_line "$root" '  ["speed"] = 2'

        # One visible tiled window receives the full workspace. Borders stay
        # dim on OLED while an active window retains subtle focus feedback.
        reject_text "$root" '"f[1]"'
        require_line "$root" '  ["workspace"] = "w[tv1]"'
        require_line "$root" '      ["active_border"] = "rgba(7aa2f7cc)",'
        require_line "$root" '      ["inactive_border"] = "rgba(292e42cc)"'

        # No Hyprland branding or wallpaper is rendered beneath clients. The
        # fallback clear remains the semantic OLED background.
        require_line "$root" '    ["background_color"] = "rgba(000000ff)",'
        require_line "$root" '    ["disable_hyprland_logo"] = true,'
        require_line "$root" '    ["force_default_wallpaper"] = 0'

        # Fullscreen HDR content may switch automatically. The desktop stays
        # in normal automatic color management until a real monitor is set.
        require_line "$root" '  ["render"] = {'
        require_line "$root" '    ["cm_auto_hdr"] = 1'

        # Hyprland implements this profile with dual-Kawase blur. Keep it
        # restrained and scope rendering to Rofi's layer-shell namespace.
        grep -F -A4 -- '    ["blur"] = {' "$root" | grep -Fqx '      ["enabled"] = true,'
        require_line "$root" '      ["passes"] = 2,'
        require_line "$root" '      ["size"] = 6'
        require_line "$root" '-- settings.layer_rule'
        require_line "$root" 'hl.layer_rule({'
        require_line "$root" '  ["blur"] = true,'
        require_line "$root" '  ["ignore_alpha"] = 0.2,'
        require_line "$root" '    ["namespace"] = "rofi"'
        require_line "$root" '  ["name"] = "rofi-blur",'
        require_line "$root" '    ["namespace"] = "swaync-notification-window"'
        require_line "$root" '  ["name"] = "swaync-notification-blur",'
        require_line "$root" '    ["namespace"] = "swaync-control-center"'
        require_line "$root" '  ["name"] = "swaync-control-center-blur",'
        test "$(grep -Fxc '  ["blur"] = true,' "$root")" -eq 3
        test "$(grep -Fxc '  ["ignore_alpha"] = 0.2,' "$root")" -eq 3
        test "$(grep -Fxc '  ["no_anim"] = true' "$root")" -eq 3

        require_line "$root" 'hl.env("XCURSOR_SIZE", "24")'
        require_line "$root" 'hl.env("XCURSOR_THEME", "capitaine-cursors-white")'

        reject_text "$generatedPrograms" 'waybar ='
        reject_text "$generatedPrograms" '  launcher ='
        reject_text "$generatedPrograms" '  uwsm ='
        reject_text "$generatedPrograms" '  cliphist ='
        reject_text "$generatedPrograms" '  rofi ='

        for program in terminal browser lock ui_launcher ui_clipboard ui_power monitor_topology wl_copy grim slurp wpctl; do
            if ! grep -Eq "^[[:space:]]+$program = \"/nix/store/.+/bin/.+\",$" "$generatedPrograms"; then
                printf 'missing Nix-resolved program: %s\n' "$program" >&2
                exit 1
            fi
        done

        touch "$out"
    ''
