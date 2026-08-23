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
    audio = ewwFiles."eww/modules/audio.yuck".source;
    audioCommand = builtins.head (builtins.filter (package: package.name == "eww-audio") homePackages);
    audioPopup = ewwFiles."eww/popups/audio.yuck".source;
    bar = ewwFiles."eww/bar.yuck".source;
    calendar = ewwFiles."eww/popups/calendar.yuck".source;
    clock = ewwFiles."eww/modules/clock.yuck".source;
    commonPopups = ewwFiles."eww/popups/common.yuck".source;
    hardware = ewwFiles."eww/modules/hardware.yuck".source;
    hardwarePopup = ewwFiles."eww/popups/hardware.yuck".source;
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
    scss = ewwFiles."eww/eww.scss".source;
    tray = ewwFiles."eww/modules/tray.yuck".source;
    theme = ewwFiles."eww/theme.scss".source;
    themeWidget = ewwFiles."eww/modules/theme.yuck".source;
    window = ewwFiles."eww/modules/window.yuck".source;
    workspaces = ewwFiles."eww/modules/workspaces.yuck".source;
    yuck = ewwFiles."eww/eww.yuck".source;
in
assert builtins.any (package: package.name == "popup-toggle") homePackages;
assert builtins.any (package: package.name == "eww-audio") homePackages;
assert builtins.any (package: package.name == "eww-hardware-status") homePackages;
assert builtins.any (package: package.name == "eww-network-listener") homePackages;
assert ewwFiles."eww/scripts/popup-toggle".executable;
assert eww.enable;
assert eww.systemd.enable;
assert eww.systemd.target == "graphical-session.target";
assert ewwService.Install.WantedBy == [ "graphical-session.target" ];
assert ewwService.Unit.After == [ "graphical-session.target" ];
assert ewwService.Unit.PartOf == [ "graphical-session.target" ];
assert ewwService.Service.ExecStart == [ "${pkgs.lib.getExe eww.package} daemon --no-daemonize" ];
assert ewwService.Service.ExecStartPost == "${pkgs.lib.getExe eww.package} --no-daemonize open bar";
assert eww.yuckConfig == null;
assert eww.scssConfig == null;
assert !waybar.enable;
assert theme == themeTokens;
pkgs.runCommandLocal "eww-base-bar-check"
    {
        nativeBuildInputs = [
            eww.package
            pkgs.dbus
            pkgs.gnused
            pkgs.jq
            pkgs.xvfb-run
            audioCommand
            hardwareStatus
            networkListener
        ];
        inherit
            audio
            audioCommand
            audioPopup
            bar
            calendar
            clock
            commonPopups
            desktopReadme
            hardware
            hardwarePopup
            network
            networkPopup
            notifications
            popupToggle
            scss
            theme
            themeWidget
            tray
            window
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
        for interface in desktop-theme popup-toggle ui-launcher ui-clipboard ui-confirm ui-power calendar hardware audio network; do
            needle=$(printf '`%s`' "$interface")
            grep -Fq -- "$needle" "$desktopReadme" || {
                printf 'missing desktop README interface: %s\n' "$interface" >&2
                exit 1
            }
        done
        grep -Fq -- '10 minutes' "$desktopReadme"
        grep -Fq -- 'mine.desktop.display.hdrMonitor' "$desktopReadme"
        grep -Fq -- 'just boundary' "$desktopReadme"

        require_line "$scss" 'window {'
        require_tabbed_line "$scss" 'background-color: transparent;'
        require_line "$yuck" '(include "./popups/common.yuck")'
        require_line "$yuck" '(include "./popups/audio.yuck")'
        require_line "$yuck" '(include "./popups/calendar.yuck")'
        require_line "$yuck" '(include "./popups/hardware.yuck")'
        require_line "$yuck" '(include "./popups/network.yuck")'
        require_line "$yuck" '(include "./modules/audio.yuck")'
        require_line "$yuck" '(include "./modules/clock.yuck")'
        require_line "$yuck" '(include "./modules/hardware.yuck")'
        require_line "$yuck" '(include "./modules/network.yuck")'
        require_line "$yuck" '(include "./modules/notifications.yuck")'
        require_line "$yuck" '(include "./modules/theme.yuck")'
        require_line "$yuck" '(include "./modules/tray.yuck")'
        require_line "$yuck" '(include "./modules/workspaces.yuck")'
        require_line "$yuck" '(include "./modules/window.yuck")'
        require_line "$yuck" '(include "./bar.yuck")'
        require_line "$bar" '    :class `bar-layout ''${theme_mode}`'
        require_line "$bar" '    :anchor "top center")'
        require_line "$bar" '  :exclusive true'
        require_line "$bar" '  :focusable "none"'
        require_line "$bar" '  :namespace "eww-bar"'
        require_line "$bar" '      (workspaces)'
        require_line "$bar" '      (active-window))'
        require_line "$bar" '      (clock))'
        require_line "$bar" '      (hardware)'
        require_line "$bar" '        (notifications)'
        require_line "$bar" '        (network)'
        require_line "$bar" '        (audio)'
        require_line "$bar" '        (tray)'
        require_line "$bar" '        (theme)))))'
        require_line "$scss" '@import "./theme.scss";'
        require_line "$commonPopups" '    :class "popup ''${kind} ''${theme_mode}"'
        require_line "$scss" '.popup {'
        require_tabbed_line "$scss" 'border: $border-width solid;'
        require_tabbed_line "$scss" 'border-radius: $radius-card;'
        require_tabbed_line "$scss" 'padding: $popup-padding;'
        require_line "$scss" '.popup.dark {'
        require_tabbed_line "$scss" 'background-color: $dark-surface;'
        require_line "$scss" '.popup.light {'
        require_tabbed_line "$scss" 'background-color: $light-surface;'
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
        for metric in CPU GPU MEM; do
            require_line "$hardware" "      (label :text \"$metric\")"
        done
        if grep -Fq '(defpoll hardware_status' "$hardware"; then
            echo 'Hardware metrics must use one long-running listener' >&2
            exit 1
        fi
        for state in unavailable warning critical; do
            grep -Fq -- "hardware-value $state" "$hardware" || {
                printf 'missing hardware bar state: %s\n' "$state" >&2
                exit 1
            }
        done
        require_line "$scss" '.hardware-dashboard {'
        require_line "$scss" '.hardware-value.warning,'
        require_line "$scss" '.hardware-value.critical,'
        require_line "$scss" '.hardware-value.unavailable {'
        require_line "$network" '(deflisten network_state'
        grep -Eq '^  `/nix/store/.+-eww-network-listener/bin/eww-network-listener listen`\)$' "$network"
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle network"$' "$network"
        require_line "$networkPopup" '(defwindow network'
        grep -Fq ':value {network_state.interface' "$networkPopup"
        grep -Fq ':value {network_state.ip' "$networkPopup"
        grep -Fq 'network_state.rx_bytes_per_second' "$networkPopup"
        grep -Fq 'network_state.tx_bytes_per_second' "$networkPopup"
        for state in wifi wired disconnected unavailable; do
            grep -Fq -- "\"$state\"" "$network" || {
                printf 'missing network state: %s\n' "$state" >&2
                exit 1
            }
        done
        require_line "$notifications" '(deflisten notification_state'
        grep -Eq '^  `/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --subscribe`\)$' "$notifications"
        grep -Eq ':onclick "/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --skip-wait --toggle-panel"' "$notifications"
        grep -Eq ':onrightclick "/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --skip-wait --toggle-dnd"' "$notifications"
        grep -Eq ':onclick "/nix/store/.+-SwayNotificationCenter-[^/]+/bin/swaync-client --skip-wait --close-all"' "$notifications"
        require_line "$notifications" '      :visible {notification_state.count > 0}'
        for state in empty unread dnd; do
            grep -Fq -- "notifications $state" "$notifications" || {
                printf 'missing notification state: %s\n' "$state" >&2
                exit 1
            }
            require_line "$scss" ".notifications.$state {"
        done
        if grep -Fq '(defpoll notification_state' "$notifications"; then
            echo 'Notification state must use swaync-client subscription' >&2
            exit 1
        fi
        require_line "$scss" '.notification-count {'
        require_line "$scss" '.notifications-dismiss-all {'
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
        grep -Eq '^  `/nix/store/.+-coreutils-[^/]+/bin/date "\+%a %b %d  %H:%M"`\)$' "$clock"
        require_line "$clock" '    :class "island clock"'
        grep -Eq '^    :onclick "/nix/store/.+-popup-toggle/bin/popup-toggle calendar"$' "$clock"
        require_line "$calendar" '  :interval "60s"'
        require_line "$calendar" '      (calendar'
        require_line "$calendar" '        :show-heading true'
        require_line "$calendar" '        :show-day-names true'
        require_line "$calendar" '    :width "320px"'
        require_line "$calendar" '  :stacking "overlay"'
        require_line "$calendar" '  :exclusive false'
        require_line "$calendar" '  :focusable "ondemand"'
        require_line "$calendar" '        :class "calendar-summary"'
        if grep -Fq ':reserve ' "$calendar"; then
            echo 'Calendar popup must not reserve screen space' >&2
            exit 1
        fi

        mkdir -p "$TMPDIR/network-bin" "$TMPDIR/network-sys/class/net/wlan0/statistics"
        cat > "$TMPDIR/network-bin/nmcli" <<'SH'
        #!/bin/sh
        set -eu
        case "$*" in
            '--terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION device status') printf '%s\n' 'wlan0:wifi:connected:Home WiFi' ;;
            '--terse --escape no --fields IN-USE,SIGNAL,SSID device wifi list ifname wlan0') printf '%s\n' '*:78:Home WiFi' ;;
            '--get-values IP4.ADDRESS device show wlan0') printf '%s\n' '192.0.2.10/24' ;;
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
            .state == "wifi" and .connected == true and .interface == "wlan0" and
            .name == "Home WiFi" and .signal == 78 and .ip == "192.0.2.10/24" and
            .rx_bytes_per_second == 0 and .tx_bytes_per_second == 0
        ' >/dev/null

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
            .rx_bytes_per_second == 1048576 and .tx_bytes_per_second == 524288
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
        require_line "$hardwarePopup" '  :focusable "ondemand"'
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
            close | open)
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
        close hardware
        close network
        open calendar'

        printf '12: calendar\n13: hardware\n' > "$EWW_ACTIVE"
        : > "$EWW_LOG"
        sh "$popup_toggle" calendar
        test "$(cat "$EWW_LOG")" = 'active-windows
        close audio
        close hardware
        close network
        close calendar'

        require_line "$workspaces" '(deflisten hyprland_state'
        require_line "$workspaces" '    (for workspace in {hyprland_state.workspaces}'
        grep -Eq ':onclick "/nix/store/.+-eww-workspace/bin/eww-workspace \$\{workspace.id\}"' "$workspaces"
        for state in empty occupied active urgent; do
            grep -Fq -- "\"$state\"" "$workspaces" || {
                printf 'missing workspace state: %s\n' "$state" >&2
                exit 1
            }
            require_line "$scss" ".workspace.$state {"
        done
        if grep -Fq '(defpoll hyprland_state' "$workspaces"; then
            echo 'Hyprland state must be event-driven' >&2
            exit 1
        fi

        require_line "$window" '      :limit-width 60'
        require_line "$window" '      :truncate true'
        require_line "$window" '      :tooltip {hyprland_state.title}'

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
        ln -s "$networkPopup" "$config_dir/popups/network.yuck"
        ln -s "$audio" "$config_dir/modules/audio.yuck"
        ln -s "$clock" "$config_dir/modules/clock.yuck"
        ln -s "$hardware" "$config_dir/modules/hardware.yuck"
        ln -s "$network" "$config_dir/modules/network.yuck"
        ln -s "$notifications" "$config_dir/modules/notifications.yuck"
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
