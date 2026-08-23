{
    desktopReadme,
    pkgs,
    eww,
    ewwFiles,
    ewwService,
    homePackages,
    themeTokens,
    waybar,
}:
let
    animationFrame = builtins.head (
        builtins.filter (package: package.name == "eww-animation-frame") homePackages
    );
    audio = ewwFiles."eww/modules/audio.yuck".source;
    audioCommand = builtins.head (builtins.filter (package: package.name == "eww-audio") homePackages);
    audioPopup = ewwFiles."eww/popups/audio.yuck".source;
    bluetooth = ewwFiles."eww/modules/bluetooth.yuck".source;
    bluetoothCommand = builtins.head (
        builtins.filter (package: package.name == "eww-bluetooth") homePackages
    );
    bar = ewwFiles."eww/bar.yuck".source;
    calendar = ewwFiles."eww/popups/calendar.yuck".source;
    clock = ewwFiles."eww/modules/clock.yuck".source;
    commonPopups = ewwFiles."eww/popups/common.yuck".source;
    hardware = ewwFiles."eww/modules/hardware.yuck".source;
    hardwarePopup = ewwFiles."eww/popups/hardware.yuck".source;
    menu = ewwFiles."eww/modules/menu.yuck".source;
    menuCommand = builtins.head (builtins.filter (package: package.name == "eww-menu") homePackages);
    menuPopup = ewwFiles."eww/popups/menu.yuck".source;
    profilePopup = ewwFiles."eww/popups/profile.yuck".source;
    hardwareStatus = builtins.head (
        builtins.filter (package: package.name == "eww-hardware-status") homePackages
    );
    network = ewwFiles."eww/modules/network.yuck".source;
    networkListener = builtins.head (
        builtins.filter (package: package.name == "eww-network-listener") homePackages
    );
    networkPopup = ewwFiles."eww/popups/network.yuck".source;
    notifications = ewwFiles."eww/modules/notifications.yuck".source;
    popupToggle = ewwFiles."eww/scripts/popup-toggle".source;
    profile = ewwFiles."eww/modules/profile.yuck".source;
    scss = ewwFiles."eww/eww.scss".source;
    iconNudges = ewwFiles."eww/icon-nudges.scss".source;
    iconMetrics = ../home/modules/hyprland/eww/icon-metrics.py;
    tray = ewwFiles."eww/modules/tray.yuck".source;
    theme = ewwFiles."eww/theme.scss".source;
    themeWidget = ewwFiles."eww/modules/theme.yuck".source;
    window = ewwFiles."eww/modules/window.yuck".source;
    workspaces = ewwFiles."eww/modules/workspaces.yuck".source;
    hyprlandListenerSource = ../home/modules/hyprland/eww/scripts/hyprland-listener.sh;
    menuSource = ../home/modules/hyprland/eww/scripts/menu.sh;
    yuck = ewwFiles."eww/eww.yuck".source;
in
assert builtins.any (package: package.name == "popup-toggle") homePackages;
assert builtins.any (package: package.name == "eww-animation-frame") homePackages;
assert builtins.any (package: package.name == "eww-audio") homePackages;
assert builtins.any (package: package.name == "eww-bluetooth") homePackages;
assert builtins.any (package: package.name == "eww-hardware-status") homePackages;
assert builtins.any (package: package.name == "eww-menu") homePackages;
assert builtins.any (package: package.name == "eww-network-listener") homePackages;
assert ewwFiles."eww/scripts/popup-toggle".executable;
assert eww.enable;
assert eww.systemd.enable;
assert eww.systemd.target == "graphical-session.target";
assert ewwService.Install.WantedBy == [ "graphical-session.target" ];
assert ewwService.Unit.After == [ "graphical-session.target" ];
assert ewwService.Unit.PartOf == [ "graphical-session.target" ];
assert ewwService.Service.ExecStart == [ "${pkgs.lib.getExe eww.package} daemon --no-daemonize" ];
# The bars are opened by a script, because the secondary one exists only when a
# second monitor is connected and opening a window for an absent monitor fails.
assert pkgs.lib.hasSuffix "/bin/eww-open-bars" ewwService.Service.ExecStartPost;
assert eww.yuckConfig == null;
assert eww.scssConfig == null;
assert !waybar.enable;
assert theme == themeTokens;
pkgs.runCommandLocal "eww-base-bar-check"
    {
        nativeBuildInputs = [
            eww.package
            pkgs.coreutils
            pkgs.dbus
            pkgs.gnused
            pkgs.jq
            pkgs.xvfb-run
            animationFrame
            audioCommand
            bluetoothCommand
            hardwareStatus
            menuCommand
            networkListener
        ];
        inherit
            audio
            audioCommand
            audioPopup
            bluetooth
            bluetoothCommand
            bar
            calendar
            clock
            commonPopups
            desktopReadme
            hardware
            hardwarePopup
            iconMetrics
            iconNudges
            menu
            menuCommand
            menuPopup
            profilePopup
            network
            networkPopup
            notifications
            popupToggle
            profile
            scss
            theme
            themeWidget
            tray
            window
            hyprlandListenerSource
            menuSource
            workspaces
            yuck
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

        mkdir -p "$TMPDIR/bluetooth-bin"
        cat > "$TMPDIR/bluetooth-bin/bluetoothctl" <<'SH'
        #!/bin/sh
        sleep 5
        SH
        chmod +x "$TMPDIR/bluetooth-bin/bluetoothctl"
        EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl" \
            timeout 2 eww-bluetooth status |
            jq -e '.available == false and .powered == false' >/dev/null

        # A powered adapter with a headset attached: connected and audio are
        # separate states because they are drawn with separate glyphs.
        mkdir -p "$TMPDIR/bluetooth-sys/class/bluetooth/hci0"
        cat > "$TMPDIR/bluetooth-bin/bluetoothctl-powered" <<'SH'
        #!/bin/sh
        set -eu
        case "$*" in
            show) printf 'Powered: yes\n' ;;
            'devices Connected') printf '%s' "''${EWW_BLUETOOTH_DEVICES-Device AA:BB:CC:DD:EE:FF Headset}" ;;
            'info AA:BB:CC:DD:EE:FF') printf 'Icon: %s\n' "''${EWW_BLUETOOTH_ICON:-audio-headset}" ;;
            *) exit 1 ;;
        esac
        SH
        chmod +x "$TMPDIR/bluetooth-bin/bluetoothctl-powered"
        EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
            EWW_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
            eww-bluetooth status |
            jq -e '.available == true and .powered == true and .connected == true and .audio == true' >/dev/null
        EWW_BLUETOOTH_ICON=input-mouse \
            EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
            EWW_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
            eww-bluetooth status |
            jq -e '.connected == true and .audio == false' >/dev/null
        EWW_BLUETOOTH_DEVICES= \
            EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
            EWW_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
            eww-bluetooth status |
            jq -e '.powered == true and .connected == false and .audio == false' >/dev/null

        # The frame is a clock read, so a fixed clock pins a known frame and
        # the sequence must wrap rather than grow.
        mkdir -p "$TMPDIR/animation-bin"
        cat > "$TMPDIR/animation-bin/date" <<'SH'
        #!/bin/sh
        printf '%s\n' "''${EWW_ANIMATION_NOW:-1000}"
        SH
        chmod +x "$TMPDIR/animation-bin/date"
        [ "$(EWW_ANIMATION_DATE="$TMPDIR/animation-bin/date" eww-animation-frame 180 8)" -eq 5 ]
        [ "$(EWW_ANIMATION_NOW=1440 EWW_ANIMATION_DATE="$TMPDIR/animation-bin/date" eww-animation-frame 180 8)" -eq 0 ]
        for arguments in '0 8' '180 0' 'x 8' '180'; do
            # shellcheck disable=SC2086
            if eww-animation-frame $arguments 2>/dev/null; then
                printf 'animation frame accepted bad arguments: %s\n' "$arguments" >&2
                exit 1
            fi
        done

        mkdir -p "$TMPDIR/hardware-proc"
        mkfifo "$TMPDIR/hardware-proc/stat"
        cat > "$TMPDIR/hardware-proc/meminfo" <<'EOF'
        MemTotal:       32768000 kB
        MemAvailable:   24576000 kB
        MemFree:         1024000 kB
        Cached:          2048000 kB
        EOF
        printf '0.72 0.65 0.60 2/1024 42\n' > "$TMPDIR/hardware-proc/loadavg"
        printf '3661.90 1200.00\n' > "$TMPDIR/hardware-proc/uptime"
        mkdir -p \
            "$TMPDIR/hardware-sys/class/hwmon/hwmon0" \
            "$TMPDIR/hardware-sys/devices/system/cpu/cpu0/cpufreq"
        printf 'coretemp\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/name"
        printf 'Package id 0\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/temp1_label"
        printf '48000\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/temp1_input"
        printf '3600000\n' > "$TMPDIR/hardware-sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        mkdir -p "$TMPDIR/hardware-bin"
        cat > "$TMPDIR/hardware-bin/nvidia-smi" <<'SH'
        #!/bin/sh
        set -eu
        printf '%s\n' "$*" >> "$EWW_NVIDIA_LOG"
        cat <<'EOF'
        0, Disabled, 88, 1024, 8192, 70, 155.50
        1, Enabled, 12, 900, 12288, 43, 35.25
        EOF
        SH
        cat > "$TMPDIR/hardware-bin/hyprctl" <<'SH'
        #!/bin/sh
        set -eu
        printf '%s\n' "$*" >> "$EWW_HYPRCTL_LOG"
        case "$*" in
            'monitors -j')
                cat <<'EOF'
        [{"name":"DP-1","width":3840,"height":2160,"refreshRate":119.88,"bitdepth":10,"colorManagementPreset":"auto","vrr":true,"focused":true}]
        EOF
                ;;
            'getoption render:cm_auto_hdr -j')
                printf '%s\n' '{"int":1}'
                ;;
            *) exit 1 ;;
        esac
        SH
        chmod +x "$TMPDIR/hardware-bin/nvidia-smi" "$TMPDIR/hardware-bin/hyprctl"
        export EWW_NVIDIA_LOG="$TMPDIR/nvidia-queries"
        export EWW_HYPRCTL_LOG="$TMPDIR/hyprctl-queries"
        {
            printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
            sleep 0.1
            printf 'cpu  150 0 150 900 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
            sleep 0.1
            printf 'cpu  200 0 200 1000 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
        } &
        stat_writer=$!
        PATH="$TMPDIR/hardware-bin:$PATH" \
            EWW_HARDWARE_HYPRCTL="$TMPDIR/hardware-bin/hyprctl" \
            EWW_HARDWARE_INTERVAL=1 \
            EWW_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
            EWW_HARDWARE_SYS_ROOT="$TMPDIR/hardware-sys" \
            ${pkgs.lib.getExe hardwareStatus} > "$TMPDIR/hardware-status" &
        hardware_pid=$!
        for _ in $(seq 1 500); do
            if [ "$(wc -l < "$TMPDIR/hardware-status")" -ge 2 ]; then
                break
            fi
            sleep 0.01
        done
        kill "$hardware_pid" >/dev/null 2>&1 || true
        wait "$hardware_pid" >/dev/null 2>&1 || true
        wait "$stat_writer"
        hardware_line=$(head -n 1 "$TMPDIR/hardware-status")
        printf '%s\n' "$hardware_line" | jq -e '
            .cpu.usage == 50 and
            .cpu.temp_c == 48 and
            .cpu.load1 == 0.72 and
            .cpu.frequency_mhz == 3600 and
            .uptime_seconds == 3661
        ' >/dev/null
        printf '%s\n' "$hardware_line" | jq -e '
            .memory.usage == 25 and
            .memory.used_gib == 7.81 and
            .memory.total_gib == 31.25
        ' >/dev/null
        printf '%s\n' "$hardware_line" | jq -e '
            .gpu.index == 1 and
            .gpu.usage == 12 and
            .gpu.vram_used_mib == 900 and
            .gpu.vram_total_mib == 12288 and
            .gpu.temp_c == 43 and
            .gpu.power_w == 35.25
        ' >/dev/null
        printf '%s\n' "$hardware_line" | jq -e '
            .display.name == "DP-1" and
            .display.width == 3840 and
            .display.height == 2160 and
            .display.refresh_hz == 119.88 and
            .display.bit_depth == 10 and
            .display.color_management_mode == "auto" and
            .display.automatic_hdr == 1 and
            .display.vrr == true
        ' >/dev/null
        test "$(cat "$EWW_NVIDIA_LOG")" = '--query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
        --query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits'
        test "$(cat "$EWW_HYPRCTL_LOG")" = 'monitors -j
        getoption render:cm_auto_hdr -j'

        mkdir -p "$TMPDIR/missing-proc" "$TMPDIR/missing-sys" "$TMPDIR/missing-bin"
        cp "$TMPDIR/hardware-proc/meminfo" "$TMPDIR/missing-proc/meminfo"
        cp "$TMPDIR/hardware-proc/loadavg" "$TMPDIR/missing-proc/loadavg"
        cp "$TMPDIR/hardware-proc/uptime" "$TMPDIR/missing-proc/uptime"
        mkfifo "$TMPDIR/missing-proc/stat"
        {
            printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/missing-proc/stat"
            sleep 0.1
            printf 'cpu  150 0 150 900 0 0 0 0 0 0\n' > "$TMPDIR/missing-proc/stat"
        } &
        missing_stat_writer=$!
        PATH="$TMPDIR/missing-bin" \
            EWW_HARDWARE_INTERVAL=1 \
            EWW_HARDWARE_PROC_ROOT="$TMPDIR/missing-proc" \
            EWW_HARDWARE_SYS_ROOT="$TMPDIR/missing-sys" \
            ${pkgs.lib.getExe hardwareStatus} > "$TMPDIR/missing-status" &
        missing_hardware_pid=$!
        for _ in $(seq 1 500); do
            if [ -s "$TMPDIR/missing-status" ]; then
                break
            fi
            sleep 0.01
        done
        kill "$missing_hardware_pid" >/dev/null 2>&1 || true
        wait "$missing_hardware_pid" >/dev/null 2>&1 || true
        wait "$missing_stat_writer"
        missing_line=$(head -n 1 "$TMPDIR/missing-status")
        printf '%s\n' "$missing_line" | jq -e '
            .cpu.temp_c == null and
            .cpu.frequency_mhz == null and
            .gpu.usage == null and
            .display.name == null and
            .display.automatic_hdr == null
        ' >/dev/null

        require_tabbed_line() {
            file=$1
            line=$2
            require_line "$file" "$(printf '\t%s' "$line")"
        }

        for heading in '## Module map' '## Theme' '## Shell interfaces' '## Service ownership' '## Idle policy' '## HDR and 10-bit output' '## Validation'; do
            grep -Fqx -- "$heading" "$desktopReadme" || {
                printf 'missing desktop README heading: %s\n' "$heading" >&2
                exit 1
            }
        done
        for interface in desktop-theme popup-toggle eww-menu ui-launcher ui-clipboard ui-confirm ui-power calendar hardware menu audio network; do
            needle=$(printf '`%s`' "$interface")
            grep -Fq -- "$needle" "$desktopReadme" || {
                printf 'missing desktop README interface: %s\n' "$interface" >&2
                exit 1
            }
        done
        grep -Fq -- '10 minutes' "$desktopReadme"
        grep -Fq -- 'mine.desktop.display.monitors' "$desktopReadme"
        grep -Fq -- 'just boundary' "$desktopReadme"

        require_line "$scss" 'window {'
        require_tabbed_line "$scss" 'background-color: transparent;'
        require_line "$yuck" '(include "./popups/common.yuck")'
        require_line "$yuck" '(include "./popups/audio.yuck")'
        require_line "$yuck" '(include "./popups/calendar.yuck")'
        require_line "$yuck" '(include "./popups/hardware.yuck")'
        require_line "$yuck" '(include "./popups/menu.yuck")'
        require_line "$yuck" '(include "./popups/network.yuck")'
        require_line "$yuck" '(include "./modules/audio.yuck")'
        require_line "$yuck" '(include "./modules/bluetooth.yuck")'
        require_line "$yuck" '(include "./modules/clock.yuck")'
        require_line "$yuck" '(include "./modules/hardware.yuck")'
        require_line "$yuck" '(include "./modules/menu.yuck")'
        require_line "$yuck" '(include "./modules/network.yuck")'
        require_line "$yuck" '(include "./modules/notifications.yuck")'
        require_line "$yuck" '(include "./modules/profile.yuck")'
        require_line "$yuck" '(include "./modules/theme.yuck")'
        require_line "$yuck" '(include "./modules/tray.yuck")'
        require_line "$yuck" '(include "./modules/workspaces.yuck")'
        require_line "$yuck" '(include "./modules/window.yuck")'
        require_line "$yuck" '(include "./bar.yuck")'
        require_line "$bar" '    :class `bar-layout ''${theme_mode}`'
        require_line "$bar" '    :y "0px"'
        require_line "$bar" '    :height "38px"'
        require_line "$bar" '    :anchor "top center")'
        require_line "$bar" '  :exclusive true'
        require_line "$bar" '  :focusable "none"'
        require_line "$bar" '  :namespace "eww-bar"'
        require_line "$bar" '      (menu)'
        require_line "$bar" '      (workspaces)'
        require_line "$bar" '      (active-window))'
        require_line "$bar" '      (clock))'
        require_line "$bar" '      (hardware)'
        # The primary controls sit in a lighter capped group; the extension is
        # the darker parent showing past that cap, never a container.
        # Wi-Fi and Ethernet are separate links, ordered around the radio
        # control they sit beside.
        require_line "$bar" '          (wifi)'
        require_line "$bar" '          (bluetooth)'
        require_line "$bar" '          (ethernet)'
        require_line "$bar" '          (audio)'
        require_line "$bar" '          (microphone))'
        require_line "$bar" '        (bar-group'
        require_line "$bar" '          :class "connection-primary"'
        require_line "$bar" '        (theme)'
        require_line "$bar" '        (notifications))'
        require_line "$bar" '      (profile))))'
        require_line "$scss" '@import "./theme.scss";'
        # Icon nudges are measured from the font at build time, so the check
        # asserts the wiring and the shape of the generated rules rather than
        # values, which change with the font.
        require_line "$scss" '@import "./icon-nudges.scss";'
        if grep -Fq '$optical-centre-nudge' "$iconNudges"; then
            echo 'Generated nudges must be absolute, not built on a shared nudge' >&2
            exit 1
        fi
        # A module appears here only when it has glyphs of its own that
        # average off-centre. Every glyph in network.yuck belongs to a named
        # control, so that module correctly has no rule at all.
        for module in bluetooth audio; do
            grep -Fq ".$module .bar-icon {" "$iconNudges" || {
                printf 'no measured nudge for module: %s\n' "$module" >&2
                exit 1
            }
        done
        # The hardware rings render with no measured compensation while their
        # offsets are re-evaluated, so each names itself with an empty nudge:
        # claimed out of the module mean, but emitting no rule.
        grep -Fq ':nudge ""' "$hardware" || {
            echo 'Hardware rings must opt out of measured nudges' >&2
            exit 1
        }
        for selector in '.hardware .bar-icon {' '.bar-icon.nudge-cpu {' \
            '.bar-icon.nudge-gpu {' '.bar-icon.nudge-memory {' \
            '.bar-icon.nudge-temperature {'; do
            if grep -Fq "$selector" "$iconNudges"; then
                printf 'hardware ring must render uncompensated: %s\n' "$selector" >&2
                exit 1
            fi
        done
        if grep -Fq '.network .bar-icon {' "$iconNudges"; then
            echo 'A named control must not also be counted in a module mean' >&2
            exit 1
        fi
        # Naming a control is what separates its ladder of state glyphs from
        # its neighbour's. Ethernet and the microphone keep their measured
        # rules; Wi-Fi reads centred with no compensation at all, so it opts
        # out under an empty name like the hardware rings.
        for named in ethernet microphone; do
            grep -Fq ".bar-icon.nudge-$named {" "$iconNudges" || {
                printf 'named icon has no measured nudge: %s\n' "$named" >&2
                exit 1
            }
        done
        grep -Fq ':nudge ""' "$network" || {
            echo 'Wi-Fi must opt out of measured nudges' >&2
            exit 1
        }
        if grep -Fq '.bar-icon.nudge-wifi {' "$iconNudges"; then
            echo 'Wi-Fi must render uncompensated' >&2
            exit 1
        fi
        # The fan glyph paints the same ink width as the GPU glyph but starts a
        # pixel inside its advance, so only a measure taken from the pen tells
        # them apart.
        grep -Fq 'return ink.x + ink.width' "$iconMetrics" || {
            echo 'Icon metrics must count the left side bearing' >&2
            exit 1
        }
        # Two classes, so the rule outranks .bar-icon whatever the order.
        if grep -Eq '^\.[a-z-]+ \{' "$iconNudges"; then
            echo 'Nudge rules must be module-scoped, not bare .bar-icon rules' >&2
            exit 1
        fi
        require_line "$commonPopups" '    :class "popup ''${kind} ''${theme_mode}"'
        # A universal font-size matches labels directly and beats the value
        # inherited from a container, which silently defeats .clock and
        # .menu-action because those classes sit on the button, not the label.
        universal_block=$(awk '/^\* \{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$scss")
        if printf '%s\n' "$universal_block" | grep -Fq 'font-size'; then
            echo 'The base font size must not be set on the universal selector' >&2
            exit 1
        fi
        grep -A5 -F 'window {' "$scss" | grep -Fq 'font-size: $font-interface-size;' || {
            echo 'The base font size must be inheritable from the window' >&2
            exit 1
        }
        # The extension is a full-height colour zone sharing a squared seam
        # with its pill, rounding only the outer end.
        # One gap everywhere: a pill boundary must not read as a bigger break
        # than the gap between two controls inside it.
        # The bar spans the screen edge to edge: an inset there would read as
        # a floating panel, and the outer margin belongs to the windows and
        # panels that sit below the bar rather than to the bar itself.
        if grep -Fq 'bar-outer-margin' "$scss"; then
            echo 'The bar must reach the screen edges' >&2
            exit 1
        fi
        if grep -Fq '.island > .theme {' "$scss"; then
            echo 'Controls on a pill must not add to the shared gap' >&2
            exit 1
        fi
        # The group is capped at both ends and states no height of its own: a
        # fixed value overflows the parent and breaks the cap out of it.
        grep -A3 -F '.bar-group {' "$scss" | grep -Fq 'border-radius: $radius-pill;' || {
            echo 'The group must be capped at both ends' >&2
            exit 1
        }
        grep -A3 -F '.bar-group {' "$scss" | grep -Fq 'min-height' && {
            echo 'The group must not state a height of its own' >&2
            exit 1
        }
        grep -A4 -F '.connection-primary {' "$scss" | grep -Fq 'background-color: $surface-hover-color;' || {
            echo 'The group must be lighter than the pill it sits on' >&2
            exit 1
        }
        awk '/\.island \{/ { seen = 1 } seen && /\.connection-island,/ { found = 1 } END { exit !found }' \
            "$scss" || {
            echo 'The pill colour must be stated after .island' >&2
            exit 1
        }
        # Icons ride the same scale as the text, so the em-based ink allowance
        # stays valid when the interface size changes.
        grep -A4 -F '.bar-icon {' "$scss" | grep -Fq 'font-size: $font-size-step-3;' || {
            echo 'Icon size must derive from the font scale' >&2
            exit 1
        }
        # No element carries a global rightward offset: each icon uses only its
        # measured rule, and centred content stays where GTK puts it.
        if grep -Fq '$optical-centre-nudge' "$scss"; then
            echo 'The optical centre nudge must not remain in the stylesheet' >&2
            exit 1
        fi
        bar_icon_block=$(awk '/^\.bar-icon \{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$scss")
        if printf '%s\n' "$bar_icon_block" | grep -Fq 'margin-left'; then
            echo 'Bar icons must carry no global nudge' >&2
            exit 1
        fi
        # Dropdown rows hover like the bar pills: lightened surface, plain
        # foreground. An accent hover elsewhere must not override it.
        for mode in dark light; do
            grep -A3 -F ".popup.$mode .menu-action:hover {" "$scss" \
                | grep -Fq "color: \$$mode-foreground;" || {
                printf 'dropdown hover must use the plain foreground: %s\n' "$mode" >&2
                exit 1
            }
        done
        if grep -Fq '.menu-action:hover,' "$scss"; then
            echo 'Dropdown rows must not join the accent hover group' >&2
            exit 1
        fi
        grep -A6 -F '.menu-action {' "$scss" | grep -Fq 'padding: $spacing-small $spacing-normal;' || {
            echo 'Dropdown rows must be padded one step in on each axis' >&2
            exit 1
        }
        require_line "$scss" '$font-size-step-1: $font-interface-size + 1px;'
        require_line "$scss" '$font-size-step-2: $font-interface-size + 2px;'
        # The bar's text and menu rows sit one step above the interface size.
        for stepped in '.window-title {:font-size: $font-size-step-1;' \
            '.menu-action {:font-size: $font-size-step-1;'; do
            stepped_size=''${stepped#*:}
            stepped=''${stepped%%:*}
            grep -A7 -F "$stepped" "$scss" | grep -Fq "$stepped_size" || {
                printf 'rule missing the stepped font size: %s\n' "$stepped" >&2
                exit 1
            }
        done
        # The date-time sits a further step above the rest of the bar text.
        require_line "$scss" '$font-size-step-3: $font-interface-size + 3px;'
        clock_size='font-size: $font-size-step-2;'
        grep -A4 -F '.workspace-number {' "$scss" | grep -Fq 'font-size: $font-size-step-1;' || {
            echo 'Workspace numbers must use the first stepped font size' >&2
            exit 1
        }
        grep -A4 -F '.clock {' "$scss" | grep -Fq "$clock_size" || {
            echo 'The clock must use the larger stepped font size' >&2
            exit 1
        }
        # GTK paints its own light default border on these surfaces, so the
        # popup must define itself by surface colour alone, like the bar.
        popup_block=$(awk '/^\.popup \{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$scss")
        printf '%s\n' "$popup_block" | grep -Fq 'border: none;' || {
            echo 'Popup must not inherit a GTK default border' >&2
            exit 1
        }
        grep -A4 -F '.menu-action {' "$scss" | grep -Fq 'border-radius: $radius-card;' || {
            echo 'Dropdown rows must follow the submenu corner radius' >&2
            exit 1
        }
        require_line "$scss" '.popup {'
        require_tabbed_line "$scss" 'border-radius: $radius-card;'
        require_tabbed_line "$scss" 'padding: $spacing-small;'
        require_line "$scss" '.popup.dark {'
        require_tabbed_line "$scss" 'background-color: $dark-surface;'
        require_line "$scss" '.popup.light {'
        require_tabbed_line "$scss" 'background-color: $light-surface;'
        require_line "$scss" '.bar-layout {'
        require_tabbed_line "$scss" 'background-color: $bar-background;'
        require_tabbed_line "$scss" 'padding: 0;'
        require_line "$scss" '$bar-background: #000000;'
        if grep -Fq '.bar-layout * {' "$scss"; then
            echo 'Bar styling must not reset descendant GTK widgets' >&2
            exit 1
        fi
        # Assert inside the rule block: a file-wide grep cannot tell whether
        # pill geometry still belongs to .island or leaked to another selector.
        island_block=$(awk '/^\.island \{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$scss")
        for property in 'background-color: $surface-hover;' 'border: 0;' \
            'border-radius: $radius-pill;' 'min-height: $bar-control;' 'padding: 0;'; do
            printf '%s\n' "$island_block" | grep -Fq -- "$property" || {
                printf 'pill geometry missing from .island: %s\n' "$property" >&2
                exit 1
            }
        done
        require_line "$scss" '.island {'
        grep -Fq -- 'background-color: $surface-hover-color;' "$scss"
        require_tabbed_line "$scss" 'border-radius: $radius-pill;'
        require_tabbed_line "$scss" 'min-height: $bar-control;'
        require_tabbed_line "$scss" 'padding: 0;'
        require_line "$scss" '.bar-cell {'
        require_tabbed_line "$scss" 'min-width: $bar-control;'
        require_tabbed_line "$scss" 'min-height: $bar-control;'
        if grep -Fq ':width ' "$hardware" || grep -Fq ':height ' "$hardware"; then
            echo 'Hardware rings must use CSS dimensions, not character-based Yuck sizing' >&2
            exit 1
        fi
        require_line "$scss" '.hardware-meter,'
        require_line "$scss" '.network-meter,'
        require_line "$scss" '.audio-meter {'
        grep -Fq -- 'background-color: $surface-color;' "$scss"
        require_line "$scss" '.bar-icon {'
        require_tabbed_line "$scss" 'font-family: $font-monospace-family;'
        require_tabbed_line "$scss" 'min-width: 0.9em;'
        # Per-module geometry stays banned. The pill group is the one exception:
        # its segments drop the edges they share so the group reads as one pill.
        for exception in '.theme-island' '.notifications-island'; do
            if grep -Fq "$exception" "$scss"; then
                printf 'per-module geometry exception in stylesheet: %s\n' "$exception" >&2
                exit 1
            fi
        done
        # The pill differs in colour only; the inset belongs to the run, as a
        # margin, because GTK boxes ignore CSS padding on the container.
        if grep -A3 '^.workspaces {' "$scss" | grep -Eq 'padding|min-width|min-height'; then
            echo 'The workspace pill may differ in colour only, not geometry' >&2
            exit 1
        fi
        require_line "$workspaces" '      :class "workspace-run"'
        grep -A7 -F '.workspace-run {' "$scss" \
            | grep -Fq 'margin: 0 ($bar-control - $workspace-control) * 0.5;' || {
            echo 'The workspace run must inset evenly on all four sides' >&2
            exit 1
        }
        # The filled glyph is the unread signal on its own.
        if grep -Fq 'notification-count' "$notifications"; then
            echo 'The notification control must not show a count beside its icon' >&2
            exit 1
        fi
        if grep -Eq 'max-(width|height)' "$scss"; then
            echo 'GTK Eww styling must not use unsupported max dimensions' >&2
            exit 1
        fi
        if grep -Fq ':width ' "$workspaces" || grep -Fq ':height ' "$workspaces"; then
            echo 'Workspace cells must use CSS dimensions, not Yuck sizing' >&2
            exit 1
        fi
        grep -Fq -- '(bar-cell' "$workspaces" || {
            echo 'Workspace cells must use the shared bar-cell primitive' >&2
            exit 1
        }
        require_line "$scss" '.workspace-label {'
        require_tabbed_line "$scss" 'border-radius: $radius-pill;'
        require_line "$yuck" '(defwidget bar-cell [class]'
        require_line "$yuck" '(defwidget bar-icon [icon ?nudge]'
        # Controls must not stretch to the bar height, or their circles turn
        # into ovals. Every structural widget centres itself vertically.
        if [ "$(grep -Fc ':valign "center"' "$yuck")" -lt 3 ]; then
            echo 'Structural bar widgets must centre vertically' >&2
            exit 1
        fi
        # The listener assembles the state classes so the markup stays one
        # short line and no class name can pick up stray whitespace.
        grep -Fq -- 'workspace-label ''${workspace.classes}' "$workspaces" || {
            echo 'Workspace cells must use the listener-provided classes' >&2
            exit 1
        }
        if grep -Fq 'workspace.occupied ?' "$workspaces"; then
            echo 'Workspace state must not be reassembled in the markup' >&2
            exit 1
        fi
        # Run the listener against a stubbed compositor. A malformed jq
        # program silently falls back to the empty seed, which loses both the
        # workspace states and the window title, so grepping is not enough.
        mkdir -p "$TMPDIR/hypr-bin"
        cat > "$TMPDIR/hypr-bin/hyprctl" <<'SH'
        #!/bin/sh
        case "$*" in
            '-j activeworkspace') printf '%s\n' '{"id":3}' ;;
            '-j clients') printf '%s\n' '[{"address":"0x1","workspace":{"id":2}},{"address":"0x2","workspace":{"id":3}},{"address":"0x3","workspace":{"id":4}},{"address":"0x4","workspace":{"id":7}}]' ;;
            '-j activewindow') printf '%s\n' '{"title":"probe","class":"probe"}' ;;
            *) exit 1 ;;
        esac
        SH
        chmod +x "$TMPDIR/hypr-bin/hyprctl"
        PATH="$TMPDIR/hypr-bin:$PATH" timeout 3 bash "$hyprlandListenerSource" \
            > "$TMPDIR/listener-out" 2> "$TMPDIR/listener-err" || true
        listener_state=$(head -n 1 "$TMPDIR/listener-out")
        if [ -s "$TMPDIR/listener-err" ]; then
            echo 'listener reported errors:' >&2
            cat "$TMPDIR/listener-err" >&2
            exit 1
        fi
        printf '%s\n' "$listener_state" | jq -e '.title == "probe"' >/dev/null
        printf '%s\n' "$listener_state" | jq -e '
            (.workspaces[1].classes == "occupied group-start")
            and (.workspaces[2].classes == "occupied active")
            and (.workspaces[3].classes == "occupied group-end")
            and (.workspaces[5].classes == "empty")
            and (.workspaces[6].classes == "occupied group-start group-end")
        ' >/dev/null

        # The focused marker lives inside the cell so the run stays continuous.
        require_line "$scss" '.workspace-label.active .workspace-number {'
        if grep -Fq '.workspace-label.active {' "$scss"; then
            echo 'The focused workspace must not replace its run segment' >&2
            exit 1
        fi
        for state in occupied empty group-start group-end active urgent; do
            grep -Fq -- "\"$state\"" "$hyprlandListenerSource" || {
                printf 'listener does not emit workspace state: %s\n' "$state" >&2
                exit 1
            }
        done
        require_line "$scss" '.workspace-label.group-start {'
        require_line "$scss" '.workspace-label.group-end {'
        require_tabbed_line "$scss" 'margin: $spacing-small * 0.5 0;'
        require_line "$scss" '.bar-cell.workspace-label {'
        require_tabbed_line "$scss" 'min-width: $workspace-control;'
        require_tabbed_line "$scss" 'min-height: $workspace-control;'
        require_line "$scss" '$workspace-control: $bar-control - $spacing-small;'
        # Every control shares one hover rule and one foreground colour.
        for control in '.audio:hover,' '.bluetooth:hover,' '.hardware:hover,' '.menu:hover,' \
            '.network:hover,' '.notifications-center:hover,' '.profile:hover,' '.workspace:hover {'; do
            require_tabbed_line "$scss" "$control"
        done
        # Hover reaches a glyph by inheritance, so no meter may pin a colour:
        # an explicit value there outranks anything inherited from the control.
        awk '/-meter,?$/ { in_meter = 1 } /^\t\}/ { in_meter = 0 }
            in_meter && /^\t\tcolor:/ { print; exit 1 }' "$scss" >&2 || {
            echo 'A meter must inherit its colour, not pin one' >&2
            exit 1
        }
        # Every control on the bar is one cell wide with one gap beside it, so
        # the pointer travels the same distance from any control to the next
        # whether or not a pill boundary falls between them. A margin on a
        # control is what breaks that, so no control may carry one.
        if grep -Eq '^\.island > \.[a-z-]+ \{' "$scss"; then
            echo 'A control on a pill must not add distance to its neighbour' >&2
            exit 1
        fi
        # A module may not colour itself to stand out. Meters are the one
        # exception: their fill encodes state the glyph cannot, so they may draw
        # on the wider palette. The rule is therefore about which selector
        # receives an attention colour, not about which colours appear at all.
        awk '
            /\{[[:space:]]*$/ { selector = $0 }
            /color:[[:space:]]*\$(accent-alt|red|yellow|green|cyan)-color;/ {
                if (selector !~ /-meter/) {
                    printf "attention colour outside a meter fill:%s in%s\n", $0, selector > "/dev/stderr"
                    exit 1
                }
            }
        ' "$scss" || exit 1
        require_line "$yuck" '(defwidget bar-section [class halign]'
        require_line "$yuck" '(defwidget bar-pill [class]'
        require_line "$yuck" '    :hexpand false'
        require_line "$yuck" '      :hexpand false'
        if [ "$(grep -Fc ':space-evenly false' "$yuck")" -lt 2 ]; then
            echo 'Structural bar widgets must opt out of even space distribution' >&2
            exit 1
        fi
        if grep -Eq '^ *\(box' "$bar"; then
            echo 'Bar layout must compose structural widgets instead of raw boxes' >&2
            exit 1
        fi
        for module in "$audio" "$hardware" "$network" "$notifications" "$workspaces"; do
            if grep -Eq '^ *\(box' "$module" && ! grep -Fq ':space-evenly false' "$module"; then
                printf 'multi-child box without explicit spacing policy in %s\n' "$module" >&2
                exit 1
            fi
        done
        if grep -Fq ':width ' "$yuck" || grep -Fq ':height ' "$yuck"; then
            echo 'Bar icons must use CSS dimensions, not character-based Yuck sizing' >&2
            exit 1
        fi
        require_line "$menu" '    (bar-icon :icon "")))'
        require_line "$profile" '    (bar-icon :icon "")))'
        require_line "$scss" '.bar-layout.dark {'
        require_line "$scss" '.bar-layout.light {'
        grep -Fq 'background-color: $dark-surface;' "$scss"
        grep -Fq 'background-color: $light-surface;' "$scss"
        grep -Fq 'color: $dark-accent;' "$scss"
        grep -Fq 'color: $light-accent;' "$scss"
        require_line "$scss" '.calendar-grid:selected {'
        require_tabbed_line "$scss" 'border: $border-width solid;'
        require_tabbed_line "$scss" 'font-weight: 700;'
        if grep -Eq 'box-shadow|filter:[[:space:]]*blur' "$scss"; then
            echo 'Popups must not use blur or shadows' >&2
            exit 1
        fi

        require_line "$theme" '$dark-surface: #16161e;'
        require_line "$theme" '$light-surface: #ffffff;'

        for icon in '' '' '' ''; do
            grep -Fq -- "\"$icon\"" "$audio" || {
                printf 'missing audio icon: %s\n' "$icon" >&2
                exit 1
            }
        done
        # An off radio keeps its control, and a connected headset is what the
        # radio is usually for, so all four states are told apart.
        for icon in '󰂯' '󰂰' '󰂱' '󰂲'; do
            grep -Fq -- "\"$icon\"" "$bluetooth" || {
                printf 'missing bluetooth icon: %s\n' "$icon" >&2
                exit 1
            }
        done
        for icon in '󰤯' '󰤟' '󰤢' '󰤥' '󰤨' '󰤭' '󰤮' '󰤫' '󰤠' '󰤣' '󰤦' '󰤩' '󰈀' '󰈂' '󰲛' '󰲝' '󰅛'; do
            grep -Fq -- "\"$icon\"" "$network" || {
                printf 'missing network icon: %s\n' "$icon" >&2
                exit 1
            }
        done
        # Do not disturb needs its own glyph because a colour-only indicator
        # reads as an empty inbox.
        # The microphone appears only while it matters: an alarm, not a
        # setting, so it costs no cell when nothing is listening.
        grep -Fq ':visible {audio_status.source.active || audio_status.source.muted}' "$audio" || {
            echo 'The microphone control must appear only while in use or muted' >&2
            exit 1
        }
        for icon in '󰍬' '󰍭'; do
            grep -Fq -- "\"$icon\"" "$audio" || {
                printf 'missing microphone icon: %s\n' "$icon" >&2
                exit 1
            }
        done
        grep -Fq -- '(bar-icon :icon {notification_state.dnd ? "󱗢"' "$notifications" || {
            echo 'Do not disturb must have a glyph of its own' >&2
            exit 1
        }
        grep -Fq -- '(bar-icon :icon "󱎖")' "$themeWidget"
        for module in "$audio" "$bluetooth" "$network" "$notifications" "$themeWidget"; do
            grep -Fq -- '(bar-icon :icon' "$module" || {
                printf 'bar icon is not in a fixed box in %s\n' "$module" >&2
                exit 1
            }
        done
        require_line "$audio" '(defpoll audio_status'
        require_line "$audio" '  :interval "2s"'
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle audio"$' "$audio"
        require_line "$audioPopup" '(defwindow audio'
        require_line "$audioPopup" '          :text {audio_status.sink.description})'
        require_line "$audioPopup" '          :text {audio_status.source.description})'
        grep -Eq ':onchange "/nix/store/.+-eww-audio/bin/eww-audio set-sink \{\}"' "$audioPopup"
        grep -Eq ':onchange "/nix/store/.+-eww-audio/bin/eww-audio set-source \{\}"' "$audioPopup"
        grep -Eq '^  `/nix/store/.+-eww-audio/bin/eww-audio status`\)$' "$audio"
        grep -Eq '^    :onmiddleclick "/nix/store/.+-eww-audio/bin/eww-audio toggle-sink"$' "$audio"
        grep -Eq '^    :onscroll "/nix/store/.+-eww-audio/bin/eww-audio change-sink \{\}"$' "$audio"
        require_line "$hardware" '(deflisten hardware_status'
        grep -Eq '^  `/nix/store/.+-eww-hardware-status/bin/eww-hardware-status`\)$' "$hardware"
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle hardware"$' "$hardware"
        require_line "$hardware" '  (circular-progress'
        for icon in '' '󰾲' ''; do
            grep -Fq -- ":icon \"$icon\"" "$hardware" || {
                printf 'missing hardware icon: %s\n' "$icon" >&2
                exit 1
            }
        done
        if grep -Fq 'hardware-value' "$hardware"; then
            echo 'Hardware bar must use circular usage indicators, not numeric values' >&2
            exit 1
        fi
        if grep -Fq '(defpoll hardware_status' "$hardware"; then
            echo 'Hardware metrics must use one long-running listener' >&2
            exit 1
        fi
        for state in unavailable warning critical; do
            grep -Fq -- "hardware-meter $state" "$hardware" || {
                printf 'missing hardware bar state: %s\n' "$state" >&2
                exit 1
            }
            # A state class is only a state if something paints it.
            grep -Fq ".hardware-meter.$state {" "$scss" || {
                printf 'hardware bar state is never painted: %s\n' "$state" >&2
                exit 1
            }
        done
        # Readings arrive in their own units, so a ring clamps to its range
        # rather than drawing past the ring or inverting it.
        for clamp in ':value {(reading ?: minimum) <= minimum ? 0' \
            ': reading >= maximum ? 100'; do
            grep -Fq -- "$clamp" "$hardware" || {
                printf 'hardware ring does not clamp: %s\n' "$clamp" >&2
                exit 1
            }
        done
        # CPU temperature is the fourth ring, measured from a floor above room
        # temperature so an idle machine reads empty.
        for setting in ':reading {hardware_status.cpu.temp_c}' ':minimum 20' \
            ':maximum 96' ':warning 60' ':critical 80'; do
            grep -Fq -- "$setting" "$hardware" || {
                printf 'temperature ring missing: %s\n' "$setting" >&2
                exit 1
            }
        done
        require_line "$scss" '.hardware-dashboard {'
        require_line "$network" '(deflisten network_state'
        # Association is drawn as motion, and the poll driving it must stop
        # when nothing is connecting rather than tick five times a second.
        require_line "$network" '  :run-while {network_state.wifi.state == "connecting"}'
        grep -Eq '^  `/nix/store/.+-eww-animation-frame/bin/eww-animation-frame 180 8`\)$' "$network" || {
            echo 'Wi-Fi association must be animated from a frame poll' >&2
            exit 1
        }
        grep -Eq '^  `/nix/store/.+-eww-network-listener/bin/eww-network-listener listen`\)$' "$network"
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle network"$' "$network"
        require_line "$networkPopup" '(defwindow network'
        # The popup describes one link, and which one is decided in the
        # listener rather than in markup.
        grep -Fq ':value {network_state.primary.interface' "$networkPopup"
        grep -Fq ':value {network_state.primary.ip' "$networkPopup"
        grep -Fq 'network_state.primary.rx_bytes_per_second' "$networkPopup"
        grep -Fq 'network_state.primary.tx_bytes_per_second' "$networkPopup"
        # Each activity half must test a floor, not bare presence of traffic. A
        # quiet link still carries hundreds of bytes per second of ARP and mDNS
        # chatter, so a > 0 predicate lights both halves permanently.
        for direction in rx tx; do
            grep -Eq ":value \{link.$direction"'_bytes_per_second >= [1-9][0-9]+ \? 50 : 0\}' "$network" || {
                printf 'network %s half must gate on a byte-rate floor\n' "$direction" >&2
                exit 1
            }
        done
        # Each link is its own control, hidden only when the machine has no
        # interface of that kind.
        for widget in '(defwidget wifi []' '(defwidget ethernet []'; do
            grep -Fq -- "$widget" "$network" || {
                printf 'missing link control: %s\n' "$widget" >&2
                exit 1
            }
        done
        # Each rung is pinned to its threshold. The two ladders share
        # thresholds and differ only by glyph, so a scrambled or copied rung
        # stays syntactically valid and silently misreports signal strength.
        for rung in '20:󰤯:󰤫' '40:󰤟:󰤠' '60:󰤢:󰤣' '80:󰤥:󰤦'; do
            threshold=''${rung%%:*}
            glyphs=''${rung#*:}
            grep -Fq "< $threshold ? \"''${glyphs%%:*}\"" "$network" || {
                printf 'signal ladder rung %s is not at its threshold\n' "$threshold" >&2
                exit 1
            }
            grep -Fq "< $threshold ? \"''${glyphs#*:}\"" "$network" || {
                printf 'alert ladder rung %s is not at its threshold\n' "$threshold" >&2
                exit 1
            }
        done
        # An unassociated radio must not borrow the alert ladder, which means
        # associated with no route out.
        grep -Fq ': "󰤮"}))' "$network" || {
            echo 'A disconnected radio needs the off glyph, not a weak-signal one' >&2
            exit 1
        }
        # A blocked radio and a down interface are one dead end, one glyph.
        grep -Fq '{network_state.wifi.state == "off" || network_state.wifi.state == "unavailable" ? "󰤭"' "$network" || {
            echo 'A down interface must share the off glyph with a blocked radio' >&2
            exit 1
        }
        grep -Fq ':visible {network_state.wifi.available}' "$network" || {
            echo 'Wi-Fi must hide only when the machine has no wireless interface' >&2
            exit 1
        }
        # With no interface of either kind there is still something to report,
        # and Ethernet is the control that reports it.
        grep -Fq ':visible {network_state.ethernet.available || !network_state.wifi.available}' "$network" || {
            echo 'Ethernet must stand in when no network interface exists' >&2
            exit 1
        }
        grep -Fq ':icon {!network_state.ethernet.available ? "󰲛"' "$network" || {
            echo 'An absent interface and an unplugged port need distinct glyphs' >&2
            exit 1
        }
        # The markup branches on the states that change what is drawn; the
        # rest only change the tooltip text.
        for state in off connecting; do
            grep -Fq -- "state == \"$state\"" "$network" || {
                printf 'missing network state branch: %s\n' "$state" >&2
                exit 1
            }
        done
        require_line "$notifications" '(deflisten notification_state'
        grep -Eq '^  `/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --subscribe`\)$' "$notifications"
        grep -Eq ':onclick "/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --skip-wait --toggle-panel"' "$notifications"
        grep -Eq ':onrightclick "/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --skip-wait --toggle-dnd"' "$notifications"
        for state in empty unread dnd; do
            grep -Fq -- "notifications $state" "$notifications" || {
                printf 'missing notification state: %s\n' "$state" >&2
                exit 1
            }
        done
        if grep -Fq '(defpoll notification_state' "$notifications"; then
            echo 'Notification state must use swaync-client subscription' >&2
            exit 1
        fi
        # The glyph swap is the whole unread signal: a second control beside
        # it widens the bar exactly when notifications arrive.
        for extra in 'notifications-dismiss-all' 'notification-count'; do
            if grep -Fq -- "$extra" "$notifications" "$scss"; then
                printf 'the unread signal must be the glyph alone: %s\n' "$extra" >&2
                exit 1
            fi
        done
        require_line "$themeWidget" '(deflisten theme_mode'
        require_line "$themeWidget" '  :initial "dark"'
        grep -Eq '^  `/nix/store/.+-eww-theme-listener/bin/eww-theme-listener`\)$' "$themeWidget"
        grep -Eq '^    :onclick "/nix/store/.+-desktop-theme/bin/desktop-theme toggle"$' "$themeWidget"
        if grep -Fq '(defpoll theme_mode' "$themeWidget"; then
            echo 'Theme mode must be event-driven' >&2
            exit 1
        fi
        require_line "$tray" '    (systray'
        require_line "$tray" '      :icon-size 16'

        require_line "$clock" '(defpoll clock_text'
        require_line "$clock" '  :interval "60s"'
        grep -Eq '^  `/nix/store/.+-coreutils-[^/]+/bin/date "\+%a %b %d %H:%M"`\)$' "$clock"
        require_line "$clock" '    :class "clock"'
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle calendar"$' "$clock"
        require_line "$calendar" '  :interval "60s"'
        require_line "$calendar" '      (calendar'
        require_line "$calendar" '        :show-heading true'
        require_line "$calendar" '        :show-day-names true'
        # Popup widths are a text measure: one column per interface font size,
        # so a larger font widens the panel instead of truncating inside it.
        require_line "$calendar" '    :width "325px"'
        for popup_width in "$menuPopup:325" "$profilePopup:221" "$audioPopup:338"; do
            grep -Fq ":width \"''${popup_width#*:}px\"" "''${popup_width%:*}" || {
                printf 'popup width not derived from the font scale: %s\n' "''${popup_width%:*}" >&2
                exit 1
            }
        done
        require_line "$calendar" '  :stacking "overlay"'
        require_line "$calendar" '  :exclusive false'
        require_line "$calendar" '  :focusable "none"'
        require_line "$calendar" '        :class "calendar-summary"'
        if grep -Fq ':reserve ' "$calendar"; then
            echo 'Calendar popup must not reserve screen space' >&2
            exit 1
        fi

        # wlan0 is wireless and carrying; no ethernet interface exists, which
        # is what must hide the Ethernet control on this machine.
        mkdir -p "$TMPDIR/network-bin" "$TMPDIR/network-sys/class/net/wlan0/statistics" \
            "$TMPDIR/network-sys/class/net/wlan0/wireless"
        printf 'up\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"
        printf '1\n' > "$TMPDIR/network-sys/class/net/wlan0/carrier"
        cat > "$TMPDIR/network-bin/nmcli" <<'SH'
        #!/bin/sh
        set -eu
        case "$*" in
            '--terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION device status') printf '%s\n' "''${EWW_NETWORK_DEVICES:-wlan0:wifi:connected:Home WiFi}" ;;
            '--terse --escape no --fields IN-USE,SIGNAL,SSID device wifi list ifname wlan0') printf '%s\n' '*:78:Home WiFi' ;;
            '--get-values IP4.ADDRESS device show wlan0') printf '%s\n' '192.0.2.10/24' ;;
            'networking connectivity') printf '%s\n' "''${EWW_NETWORK_CONNECTIVITY:-full}" ;;
            'radio wifi') printf '%s\n' "''${EWW_NETWORK_WIFI_RADIO:-enabled}" ;;
            *) exit 1 ;;
        esac
        SH
        chmod +x "$TMPDIR/network-bin/nmcli"
        printf '1048576\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"
        printf '524288\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
        network_status=$(
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            eww-network-listener status
        )
        printf '%s\n' "$network_status" | jq -e '
            .wifi.available == true and .wifi.state == "connected" and .wifi.connected == true and
            .wifi.internet == true and .wifi.interface == "wlan0" and .wifi.name == "Home WiFi" and
            .wifi.signal == 78 and .wifi.ip == "192.0.2.10/24" and
            .wifi.rx_bytes_per_second == 0 and .wifi.tx_bytes_per_second == 0 and
            .ethernet.available == false and .primary.kind == "wifi"
        ' >/dev/null
        EWW_NETWORK_CONNECTIVITY=limited \
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            eww-network-listener status |
            jq -e '.wifi.connected == true and .wifi.internet == false' >/dev/null
        EWW_NETWORK_DEVICES='wlan0:wifi:disconnected:--' \
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            EWW_NETWORK_WIFI_RADIO=disabled \
            eww-network-listener status |
            jq -e '.wifi.available == true and .wifi.state == "off" and .wifi.connected == false' >/dev/null
        EWW_NETWORK_DEVICES='wlan0:wifi:disconnected:--' \
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            eww-network-listener status |
            jq -e '.wifi.available == true and .wifi.state == "disconnected" and .wifi.connected == false' >/dev/null
        printf 'down\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"
        EWW_NETWORK_DEVICES='wlan0:wifi:disconnected:--' \
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            eww-network-listener status |
            jq -e '.wifi.available == true and .wifi.state == "unavailable"' >/dev/null
        printf 'up\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"

        mkdir -p "$TMPDIR/network-fallback-sys/class/net/eno1" \
            "$TMPDIR/network-fallback-sys/class/net/wlan0/wireless" \
            "$TMPDIR/network-fallback-proc/net"
        printf 'up\n' > "$TMPDIR/network-fallback-sys/class/net/eno1/operstate"
        printf '1\n' > "$TMPDIR/network-fallback-sys/class/net/eno1/carrier"
        printf 'up\n' > "$TMPDIR/network-fallback-sys/class/net/wlan0/operstate"
        printf '1\n' > "$TMPDIR/network-fallback-sys/class/net/wlan0/carrier"
        printf 'Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n' > "$TMPDIR/network-fallback-proc/net/route"
        printf 'eno1\t00000000\t00000000\t0003\t0\t0\t100\t00000000\t0\t0\t0\n' >> "$TMPDIR/network-fallback-proc/net/route"
        cat > "$TMPDIR/network-bin/nmcli-unavailable" <<'SH'
        #!/bin/sh
        exit 1
        SH
        chmod +x "$TMPDIR/network-bin/nmcli-unavailable"
        EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli-unavailable" \
            EWW_NETWORK_PROC_ROOT="$TMPDIR/network-fallback-proc" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-fallback-sys" \
            eww-network-listener status |
            jq -e '.ethernet.state == "connected" and .ethernet.connected == true and
                   .ethernet.interface == "eno1" and .wifi.available == true and
                   .primary.kind == "ethernet"' >/dev/null

        cat > "$TMPDIR/network-bin/date" <<'SH'
        #!/bin/sh
        set -eu
        count=0
        [ ! -f "$EWW_NETWORK_DATE_COUNT" ] || read -r count < "$EWW_NETWORK_DATE_COUNT"
        count=$((count + 1))
        printf '%s\n' "$count" > "$EWW_NETWORK_DATE_COUNT"
        if [ "$count" -eq 1 ]; then
            printf '100\n'
        else
            printf '102\n'
        fi
        SH
        chmod +x "$TMPDIR/network-bin/date"
        rm "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes" \
            "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
        mkfifo "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes" \
            "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
        { printf '1048576\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"; printf '3145728\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"; } &
        network_rx_writer=$!
        { printf '524288\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"; printf '1572864\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"; } &
        network_tx_writer=$!
        EWW_NETWORK_DATE="$TMPDIR/network-bin/date" \
            EWW_NETWORK_DATE_COUNT="$TMPDIR/network-date-count" \
            EWW_NETWORK_INTERVAL=0.01 \
            EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
            EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
            eww-network-listener listen > "$TMPDIR/network-listener" &
        network_pid=$!
        for _ in $(seq 1 500); do
            [ "$(wc -l < "$TMPDIR/network-listener")" -ge 2 ] && break
            sleep 0.01
        done
        kill "$network_pid" >/dev/null 2>&1 || true
        wait "$network_pid" >/dev/null 2>&1 || true
        wait "$network_rx_writer" "$network_tx_writer"
        sed -n '2p' "$TMPDIR/network-listener" | jq -e '
            .wifi.rx_bytes_per_second == 1048576 and .wifi.tx_bytes_per_second == 524288
        ' >/dev/null

        mkdir -p "$TMPDIR/audio-bin"
        cat > "$TMPDIR/audio-bin/wpctl" <<'SH'
        #!/bin/sh
        set -eu
        case "$*" in
            'get-volume @DEFAULT_AUDIO_SINK@') printf '%s\n' 'Volume: 0.42 [MUTED]' ;;
            'get-volume @DEFAULT_AUDIO_SOURCE@') printf '%s\n' 'Volume: 0.73' ;;
            'inspect @DEFAULT_AUDIO_SINK@') [ "''${EWW_AUDIO_INSPECT_FAIL:-0}" -eq 0 ] || exit 1; printf '%s\n' 'node.description = "Speakers"' ;;
            'inspect @DEFAULT_AUDIO_SOURCE@') [ "''${EWW_AUDIO_INSPECT_FAIL:-0}" -eq 0 ] || exit 1; printf '%s\n' 'node.description = "Microphone"' ;;
            'set-mute @DEFAULT_AUDIO_SINK@ toggle' | 'set-mute @DEFAULT_AUDIO_SOURCE@ toggle' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+' | 'set-volume @DEFAULT_AUDIO_SINK@ 5%-' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%' | 'set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%') printf '%s\n' "$*" >> "$EWW_AUDIO_LOG" ;;
            *) exit 1 ;;
        esac
        SH
        chmod +x "$TMPDIR/audio-bin/wpctl"
        export EWW_AUDIO_LOG="$TMPDIR/audio-actions"
        audio_status=$(EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status)
        printf '%s\n' "$audio_status" | jq -e '
            .available == true and
            .sink.muted == true and .sink.volume == 42 and .sink.description == "Speakers" and
            .source.muted == false and .source.volume == 73 and .source.description == "Microphone"
        ' >/dev/null
        EWW_AUDIO_INSPECT_FAIL=1 EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status |
            jq -e '.sink.description == "Default audio device" and .source.description == "Default audio device"' >/dev/null

        # Capture detection: a running input stream means an application holds
        # the microphone open. An idle stream does not, and neither does a
        # graph that cannot be read.
        cat > "$TMPDIR/audio-bin/pw-dump" <<'SH'
        #!/bin/sh
        set -eu
        cat "$EWW_AUDIO_GRAPH"
        SH
        chmod +x "$TMPDIR/audio-bin/pw-dump"
        cat > "$TMPDIR/audio-graph-running" <<'JSON'
        [{"type":"PipeWire:Interface:Node",
          "info":{"state":"running","props":{"media.class":"Stream/Input/Audio","application.name":"Firefox"}}}]
        JSON
        cat > "$TMPDIR/audio-graph-idle" <<'JSON'
        [{"type":"PipeWire:Interface:Node",
          "info":{"state":"suspended","props":{"media.class":"Stream/Input/Audio","application.name":"Firefox"}}}]
        JSON
        EWW_AUDIO_GRAPH="$TMPDIR/audio-graph-running" \
            EWW_AUDIO_PWDUMP="$TMPDIR/audio-bin/pw-dump" \
            EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status |
            jq -e '.source.active == true and .source.clients == ["Firefox"]' >/dev/null
        EWW_AUDIO_GRAPH="$TMPDIR/audio-graph-idle" \
            EWW_AUDIO_PWDUMP="$TMPDIR/audio-bin/pw-dump" \
            EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status |
            jq -e '.source.active == false and .source.clients == []' >/dev/null
        EWW_AUDIO_PWDUMP="$TMPDIR/audio-bin/missing-pw-dump" \
            EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status |
            jq -e '.source.active == false' >/dev/null
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio toggle-sink
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio toggle-source
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-sink up
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-sink down
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio set-sink 55
        EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio set-source 31.5
        if EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio set-sink 101 >/dev/null 2>&1; then
            echo 'eww-audio accepted volume above its limit' >&2
            exit 1
        fi
        test "$(cat "$EWW_AUDIO_LOG")" = 'set-mute @DEFAULT_AUDIO_SINK@ toggle
        set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        set-volume @DEFAULT_AUDIO_SINK@ 5%-
        set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%
        set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%'

        require_line "$hardwarePopup" '(defwindow hardware'
        require_line "$hardwarePopup" '  :stacking "overlay"'
        require_line "$hardwarePopup" '  :exclusive false'
        require_line "$hardwarePopup" '  :focusable "none"'
        for section in CPU GPU Memory Display Uptime; do
            grep -Fq -- ":text \"$section\"" "$hardwarePopup" || {
                printf 'missing hardware dashboard section: %s\n' "$section" >&2
                exit 1
            }
        done
        grep -Fq -- '"Unavailable"' "$hardwarePopup"
        for detail in Output Mode 'Bit depth' 'Color management' 'Automatic HDR' VRR; do
            grep -Fq -- ":name \"$detail\"" "$hardwarePopup" || {
                printf 'missing display detail: %s\n' "$detail" >&2
                exit 1
            }
        done

        popup_toggle="$TMPDIR/popup-toggle"
        mkdir -p "$TMPDIR/bin"
        sed \
            -e "s|${pkgs.lib.getExe eww.package}|$TMPDIR/bin/eww|g" \
            "$popupToggle" > "$popup_toggle"
        cat > "$TMPDIR/bin/eww" <<'SH'
        #!/bin/sh
        set -eu

        printf '%s\n' "$*" >> "$EWW_LOG"
        case "$1" in
            active-windows)
                cat "$EWW_ACTIVE"
                ;;
            close | open | update)
                ;;
            *)
                exit 1
                ;;
        esac
        SH
        chmod +x "$TMPDIR/bin/eww"
        export EWW_LOG="$TMPDIR/eww-actions"
        export EWW_ACTIVE="$TMPDIR/eww-active-windows"
        : > "$EWW_LOG"
        printf '11: hardware\n' > "$EWW_ACTIVE"

        if sh "$popup_toggle" >/dev/null 2>&1; then
            echo 'popup-toggle accepted a missing popup name' >&2
            exit 1
        fi
        if sh "$popup_toggle" unknown >/dev/null 2>&1; then
            echo 'popup-toggle accepted an unknown popup name' >&2
            exit 1
        fi
        test ! -s "$EWW_LOG"

        sh "$popup_toggle" calendar
        test "$(cat "$EWW_LOG")" = 'active-windows
        close audio
        close calendar
        close hardware
        close menu
        close network
        close profile
        close popup-backdrop
        close popup-backdrop-secondary
        update open_popup=
        open popup-backdrop
        open popup-backdrop-secondary
        open calendar
        update open_popup=calendar'

        printf '12: calendar\n13: hardware\n' > "$EWW_ACTIVE"
        : > "$EWW_LOG"
        sh "$popup_toggle" calendar
        test "$(cat "$EWW_LOG")" = 'active-windows
        close audio
        close calendar
        close hardware
        close menu
        close network
        close profile
        close popup-backdrop
        close popup-backdrop-secondary
        update open_popup='

        : > "$EWW_LOG"
        sh "$popup_toggle" close-all
        test "$(cat "$EWW_LOG")" = 'close audio
        close calendar
        close hardware
        close menu
        close network
        close profile
        close popup-backdrop
        close popup-backdrop-secondary
        update open_popup='

        grep -Eq ':action "/nix/store/.+-popup-toggle/bin/popup-toggle hardware"' "$menuPopup"
        grep -Eq ':action "/nix/store/.+-eww-menu/bin/eww-menu (reload-compositor|terminal|force-quit|quit)"' \
            "$menuPopup" || {
            echo 'menu actions do not match the expected set' >&2
            exit 1
        }
        # Virtual-terminal switching requires a pkexec/chvt privilege path, so
        # the menu must expose neither.
        for removed in 'virtual-terminal' 'Enter virtual terminal'; do
            if grep -Fq "$removed" "$menuPopup"; then
                printf 'virtual terminal action still present: %s\n' "$removed" >&2
                exit 1
            fi
        done
        if grep -Eq 'pkexec|chvt' "$menuSource"; then
            echo 'menu script must not retain the virtual terminal privilege path' >&2
            exit 1
        fi
        # Labels signal what follows: an ellipsis for a further choice, and the
        # quoted title for the window that will actually be closed.
        require_line "$menuPopup" '        (label :xalign 0 :text "Force quit ..."))'
        # The application name, not the live window title, so the label does
        # not change as the focused window retitles itself.
        grep -Eq "Quit .[^ ]*hyprland_state\.app" "$menuPopup" || {
            echo 'Quit label must name the application in quotes' >&2
            exit 1
        }
        for state in app initialTitle class address; do
            grep -Fq -- "$state" "$hyprlandListenerSource" || {
                printf 'listener does not derive the application name: %s\n' "$state" >&2
                exit 1
            }
        done
        grep -Fq '"Quit focused window"' "$menuPopup" || {
            echo 'Quit label must name a fallback for an empty title' >&2
            exit 1
        }
        # The profile control opens the same dropdown shape as the left menu.
        require_line "$profilePopup" '(defwindow profile'
        require_line "$profilePopup" '  :focusable "none"'
        grep -Fq -- '(popup-action :action' "$profilePopup" || {
            echo 'Profile menu must reuse the shared dropdown row widget' >&2
            exit 1
        }
        for label in Lock 'Log out' Sleep Hibernate Reboot 'Power off'; do
            grep -Fq -- ":text \"$label\"" "$profilePopup" || {
                printf 'missing profile action: %s\n' "$label" >&2
                exit 1
            }
        done
        grep -Eq ':action "/nix/store/.+-ui-power/bin/ui-power (lock|logout|sleep|hibernate|reboot|poweroff)"' "$profilePopup"
        for label in 'System information' 'Reload compositor' 'Open terminal' 'Force quit ...'; do
            grep -Fq -- ":text \"$label\"" "$menuPopup" || {
                printf 'missing menu action: %s\n' "$label" >&2
                exit 1
            }
        done
        grep -Eq "Quit .[^ ]*hyprland_state\.app" "$menuPopup" || {
            echo 'Quit label must name the application' >&2
            exit 1
        }

        mkdir -p "$TMPDIR/menu-bin"
        cat > "$TMPDIR/menu-bin/eww" <<'SH'
        #!/bin/sh
        printf 'eww:%s\n' "$*" >> "$EWW_MENU_TEST_LOG"
        SH
        cat > "$TMPDIR/menu-bin/hyprctl" <<'SH'
        #!/bin/sh
        printf 'hyprctl:%s\n' "$*" >> "$EWW_MENU_TEST_LOG"
        SH
        cat > "$TMPDIR/menu-bin/pkexec" <<'SH'
        #!/bin/sh
        printf 'pkexec:%s\n' "$*" >> "$EWW_MENU_TEST_LOG"
        SH
        cat > "$TMPDIR/menu-bin/terminal" <<'SH'
        #!/bin/sh
        printf 'terminal:%s\n' "$*" >> "$EWW_MENU_TEST_LOG"
        SH
        : > "$TMPDIR/menu-bin/btop"
        chmod +x "$TMPDIR/menu-bin"/*
        export EWW_MENU_BTOP="$TMPDIR/menu-bin/btop"
        export EWW_MENU_EWW="$TMPDIR/menu-bin/eww"
        export EWW_MENU_HYPRCTL="$TMPDIR/menu-bin/hyprctl"
        export EWW_MENU_TERMINAL="$TMPDIR/menu-bin/terminal"
        export EWW_MENU_TEST_LOG="$TMPDIR/menu-actions"

        : > "$EWW_MENU_TEST_LOG"
        eww-menu reload-compositor
        test "$(cat "$EWW_MENU_TEST_LOG")" = 'eww:close menu
        hyprctl:reload'
        : > "$EWW_MENU_TEST_LOG"
        eww-menu terminal
        test "$(cat "$EWW_MENU_TEST_LOG")" = 'eww:close menu
        terminal:'
        : > "$EWW_MENU_TEST_LOG"
        eww-menu force-quit
        test "$(cat "$EWW_MENU_TEST_LOG")" = "eww:close menu
        hyprctl:dispatch hl.dsp.exec_cmd('[float; center; size 1100 720] $EWW_MENU_TERMINAL -e $EWW_MENU_BTOP')"
        # Closing the menu can leave no active window, so quit closes the very
        # window the label named.
        : > "$EWW_MENU_TEST_LOG"
        eww-menu quit 0xdeadbeef
        test "$(cat "$EWW_MENU_TEST_LOG")" = 'eww:close menu
        hyprctl:dispatch hl.dsp.window.close({ address = '"'"'0xdeadbeef'"'"' })'
        : > "$EWW_MENU_TEST_LOG"
        eww-menu quit
        test "$(cat "$EWW_MENU_TEST_LOG")" = 'eww:close menu
        hyprctl:dispatch hl.dsp.window.close()'
        : > "$EWW_MENU_TEST_LOG"
        if eww-menu unknown >/dev/null 2>&1; then
            echo 'eww-menu accepted an unknown action' >&2
            exit 1
        fi
        test ! -s "$EWW_MENU_TEST_LOG"

        require_line "$workspaces" '(deflisten hyprland_state'
        require_line "$workspaces" '      (for workspace in {hyprland_state.workspaces}'
        grep -Eq ':onclick "/nix/store/.+-eww-workspace/bin/eww-workspace \$\{workspace.id\}"' "$workspaces"
        for state in empty occupied active urgent; do
            grep -Fq -- "\"$state\"" "$workspaces" || {
                printf 'missing workspace state: %s\n' "$state" >&2
                exit 1
            }
        done
        require_line "$scss" '.workspace-label {'
        require_line "$scss" '.workspace-label.active,'
        require_line "$scss" '.workspace-label.urgent {'
        if grep -Fq '(defpoll hyprland_state' "$workspaces"; then
            echo 'Hyprland state must be event-driven' >&2
            exit 1
        fi

        require_line "$menu" '    :class "menu"'
        require_line "$menu" '    (bar-icon :icon "")))'
        require_line "$profile" '    (bar-icon :icon "")))'
        if grep -Eq ':class "island (active-window|clock|profile)"' "$window" "$clock" "$profile"; then
            echo 'Window title, date-time, and profile must not use pill containers' >&2
            exit 1
        fi
        require_line "$window" '      :limit-width 60'
        require_line "$window" '      :truncate true'
        require_line "$window" '      :tooltip {hyprland_state.title}'

        # A tooltip that stays up while its own menu is open covers the first
        # entry of that menu, so a control drops its tooltip while it is open.
        require_line "$yuck" '(defvar open_popup "")'
        # Set when a popup opens and cleared when any closes, so the state
        # cannot outlive the window it describes.
        test "$(grep -c 'update open_popup=' "$popupToggle")" = 2 || {
            echo 'The open popup must be published on both open and close' >&2
            exit 1
        }
        grep -Fq 'update open_popup="$popup_name"' "$popupToggle" || {
            echo 'The published name must be the popup that opened' >&2
            exit 1
        }
        for control in menu hardware profile audio network; do
            eval "source=\$$control"
            grep -Fq "open_popup == \"$control\" ? \"\" :" "$source" || {
                printf 'control keeps its tooltip while open: %s\n' "$control" >&2
                exit 1
            }
        done
        # A workspace is a number you can already read, and its tooltip covers
        # the workspaces on either side of the one being aimed at.
        if grep -Fq ':tooltip' "$workspaces"; then
            echo 'A workspace label must not carry a tooltip' >&2
            exit 1
        fi
        # One separator across every tooltip.
        for source in "$audio" "$bluetooth" "$network" "$themeWidget" "$notifications"; do
            if grep -Fq -- '—' "$source"; then
                printf 'tooltip uses a dash rather than the shared dot: %s\n' "$source" >&2
                exit 1
            fi
        done

        config_dir="$TMPDIR/eww"
        mkdir -p "$config_dir/modules" "$config_dir/popups"
        ln -s "$yuck" "$config_dir/eww.yuck"
        ln -s "$scss" "$config_dir/eww.scss"
        ln -s "$theme" "$config_dir/theme.scss"
        ln -s "$bar" "$config_dir/bar.yuck"
        ln -s "$commonPopups" "$config_dir/popups/common.yuck"
        ln -s "$audioPopup" "$config_dir/popups/audio.yuck"
        ln -s "$calendar" "$config_dir/popups/calendar.yuck"
        ln -s "$hardwarePopup" "$config_dir/popups/hardware.yuck"
        ln -s "$menuPopup" "$config_dir/popups/menu.yuck"
        ln -s "$profilePopup" "$config_dir/popups/profile.yuck"
        ln -s "$networkPopup" "$config_dir/popups/network.yuck"
        ln -s "$audio" "$config_dir/modules/audio.yuck"
        ln -s "$bluetooth" "$config_dir/modules/bluetooth.yuck"
        ln -s "$clock" "$config_dir/modules/clock.yuck"
        ln -s "$hardware" "$config_dir/modules/hardware.yuck"
        ln -s "$menu" "$config_dir/modules/menu.yuck"
        ln -s "$network" "$config_dir/modules/network.yuck"
        ln -s "$notifications" "$config_dir/modules/notifications.yuck"
        ln -s "$profile" "$config_dir/modules/profile.yuck"
        ln -s "$themeWidget" "$config_dir/modules/theme.yuck"
        ln -s "$tray" "$config_dir/modules/tray.yuck"
        ln -s "$window" "$config_dir/modules/window.yuck"
        ln -s "$workspaces" "$config_dir/modules/workspaces.yuck"

        export HOME="$TMPDIR/home"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -m 700 -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

        cat > "$TMPDIR/eww-smoke" <<'SH'
        #!/bin/sh
        set -eu

        config_dir=$1
        log=$2

        eww --config "$config_dir" daemon --no-daemonize >"$log" 2>&1 &
        daemon_pid=$!

        cleanup() {
            eww --config "$config_dir" kill >/dev/null 2>&1 || true
            kill "$daemon_pid" >/dev/null 2>&1 || true
            wait "$daemon_pid" >/dev/null 2>&1 || true
        }
        trap cleanup EXIT HUP INT TERM

        sleep 1
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            wait "$daemon_pid" || true
            cat "$log" >&2
            exit 1
        fi

        eww --config "$config_dir" ping >/dev/null
        eww --no-daemonize --config "$config_dir" open bar >/dev/null
        eww --no-daemonize --config "$config_dir" open audio >/dev/null
        eww --no-daemonize --config "$config_dir" open calendar >/dev/null
        eww --no-daemonize --config "$config_dir" open hardware >/dev/null
        eww --no-daemonize --config "$config_dir" open network >/dev/null
        eww --no-daemonize --config "$config_dir" open profile >/dev/null
        eww --no-daemonize --config "$config_dir" open popup-backdrop >/dev/null
        eww --config "$config_dir" debug >/dev/null
        eww --config "$config_dir" kill >/dev/null
        wait "$daemon_pid" || true
        trap - EXIT HUP INT TERM
        SH
        chmod +x "$TMPDIR/eww-smoke"

        if ! dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
            xvfb-run -a "$TMPDIR/eww-smoke" "$config_dir" "$TMPDIR/eww.log"; then
            if [ -f "$TMPDIR/eww.log" ]; then
                cat "$TMPDIR/eww.log" >&2
            fi
            exit 1
        fi

        touch "$out"
    ''
