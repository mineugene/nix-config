{
    pkgs,
    monitorTopology,
    monitorTopologyService,
}:
assert monitorTopologyService.Unit.PartOf == [ "graphical-session.target" ];
assert monitorTopologyService.Install.WantedBy == [ "graphical-session.target" ];
assert !(monitorTopologyService.Service ? ExecStartPre);
assert monitorTopologyService.Service.ExecStart == [ "${monitorTopology} watch" ];
assert monitorTopologyService.Service.Restart == "on-failure";
pkgs.runCommandLocal "monitor-topology-check"
    {
        nativeBuildInputs = [ pkgs.jq ];
        inherit monitorTopology;
    }
    ''
        set -eu

        bin="$TMPDIR/bin"
        state="$TMPDIR/state"
        calls="$TMPDIR/hyprctl-calls"
        mkdir -p "$bin" "$state/monitor-topologies"

        cat > "$bin/hyprctl" <<'SH'
        #!${pkgs.runtimeShell}
        set -eu

        if [ "$1" = "-j" ] && [ "$2" = "monitors" ] && [ "$3" = "all" ]; then
            if [ -n "''${HYPRCTL_DELAYED_MONITORS:-}" ]; then
                status_count=$(cat "$HYPRCTL_STATUS_COUNT")
                status_count=$((status_count + 1))
                printf '%s\n' "$status_count" > "$HYPRCTL_STATUS_COUNT"
                if [ "$status_count" -ge 105 ]; then
                    cp "$HYPRCTL_DELAYED_MONITORS" "$MONITORS"
                fi
            fi
            cat "$MONITORS"
            exit 0
        fi

        if [ "$1" = "eval" ]; then
            printf '%s\n' "$2" >> "$HYPRCTL_CALLS"
            if [ "''${HYPRCTL_EVAL_ERROR:-}" = 1 ]; then
                printf 'lua evaluation failed\n'
            else
                case "$2" in
                    hl.monitor*)
                        if [ -z "''${HYPRCTL_DELAYED_MONITORS:-}" ]; then
                            eval_count=$(cat "$HYPRCTL_EVAL_COUNT")
                            eval_count=$((eval_count + 1))
                            printf '%s\n' "$eval_count" > "$HYPRCTL_EVAL_COUNT"
                            if [ "$eval_count" -eq 2 ]; then
                                cp "$HYPRCTL_APPLIED_MONITORS" "$MONITORS"
                            fi
                        fi
                        ;;
                esac
                printf 'ok\n'
            fi
            exit 0
        fi

        printf 'unexpected hyprctl call: %s\n' "$*" >&2
        exit 1
        SH
        chmod +x "$bin/hyprctl"

        cat > "$TMPDIR/monitors.json" <<'JSON'
        [
          {
            "name": "DP-3",
            "make": "Example Displays",
            "model": "Bottom Panel",
            "serial": "BOTTOM-001",
            "width": 2560,
            "height": 1440,
            "refreshRate": 59.951,
            "x": 0,
            "y": 0,
            "scale": 1,
            "transform": 0,
            "focused": true,
            "disabled": false
          },
          {
            "name": "DP-4",
            "make": "Acme Displays",
            "model": "Top Panel",
            "serial": "TOP-001",
            "width": 2560,
            "height": 1440,
            "refreshRate": 59.951,
            "x": 2560,
            "y": 0,
            "scale": 1,
            "transform": 0,
            "focused": false,
            "disabled": false
          }
        ]
        JSON
        cp "$TMPDIR/monitors.json" "$TMPDIR/default-monitors.json"

        cat > "$state/monitor-topologies/layouts.json" <<'JSON'
        {
          "version": 1,
          "layouts": [
            {
              "topology": [
                { "make": "Acme Displays", "model": "Top Panel", "serial": "TOP-001" },
                { "make": "Example Displays", "model": "Bottom Panel", "serial": "BOTTOM-001" }
              ],
              "monitors": [
                {
                  "identity": { "make": "Acme Displays", "model": "Top Panel", "serial": "TOP-001" },
                  "width": 2560,
                  "height": 1440,
                  "refresh": 180,
                  "x": 0,
                  "y": 0,
                  "scale": 1,
                  "transform": 0,
                  "primary": false
                },
                {
                  "identity": { "make": "Example Displays", "model": "Bottom Panel", "serial": "BOTTOM-001" },
                  "width": 2560,
                  "height": 1440,
                  "refresh": 359.98,
                  "x": 0,
                  "y": 1440,
                  "scale": 1,
                  "transform": 0,
                  "primary": true
                }
              ]
            }
          ]
        }
        JSON
        cp "$state/monitor-topologies/layouts.json" "$TMPDIR/restorable-layouts.json"
        cat > "$TMPDIR/applied-monitors.json" <<'JSON'
        [
          {
            "name": "DP-3", "make": "Example Displays", "model": "Bottom Panel", "serial": "BOTTOM-001",
            "width": 2560, "height": 1440, "refreshRate": 359.979,
            "x": 0, "y": 1440, "scale": 1, "transform": 0, "focused": true, "disabled": false
          },
          {
            "name": "DP-4", "make": "Acme Displays", "model": "Top Panel", "serial": "TOP-001",
            "width": 2560, "height": 1440, "refreshRate": 179.999,
            "x": 0, "y": 0, "scale": 1, "transform": 0, "focused": false, "disabled": false
          }
        ]
        JSON
        printf '0\n' > "$TMPDIR/eval-count"

        MONITOR_TOPOLOGY_HYPRCTL="$bin/hyprctl" \
            HYPRCTL_APPLIED_MONITORS="$TMPDIR/applied-monitors.json" \
            HYPRCTL_EVAL_COUNT="$TMPDIR/eval-count" \
            MONITORS="$TMPDIR/monitors.json" \
            HYPRCTL_CALLS="$calls" \
            XDG_STATE_HOME="$state" \
            "$monitorTopology" apply

        cat > "$TMPDIR/expected-apply" <<'CALLS'
        hl.monitor({ output = "DP-4", mode = "2560x1440@180", position = "0x0", scale = 1, transform = 0 })
        hl.monitor({ output = "DP-3", mode = "2560x1440@359.98", position = "0x1440", scale = 1, transform = 0 })
        hl.dispatch(hl.dsp.focus({ monitor = "DP-3" })); hl.dispatch(hl.dsp.cursor.move({ x = 1280, y = 2160 }))
        CALLS
        cmp "$TMPDIR/expected-apply" "$calls"

        cp "$TMPDIR/default-monitors.json" "$TMPDIR/monitors.json"
        printf '0\n' > "$TMPDIR/status-count"
        printf '0\n' > "$TMPDIR/eval-count"
        : > "$calls"
        MONITOR_TOPOLOGY_HYPRCTL="$bin/hyprctl" \
            HYPRCTL_DELAYED_MONITORS="$TMPDIR/applied-monitors.json" \
            HYPRCTL_STATUS_COUNT="$TMPDIR/status-count" \
            HYPRCTL_EVAL_COUNT="$TMPDIR/eval-count" \
            MONITORS="$TMPDIR/monitors.json" \
            HYPRCTL_CALLS="$calls" \
            XDG_STATE_HOME="$state" \
            "$monitorTopology" apply
        cmp "$TMPDIR/expected-apply" "$calls"

        if MONITOR_TOPOLOGY_HYPRCTL="$bin/hyprctl" \
            HYPRCTL_EVAL_ERROR=1 \
            MONITORS="$TMPDIR/monitors.json" \
            HYPRCTL_CALLS="$calls" \
            XDG_STATE_HOME="$state" \
            "$monitorTopology" apply > "$TMPDIR/eval-error.out" 2>&1; then
            printf 'monitor-topology accepted a failed Lua evaluation\n' >&2
            exit 1
        fi
        grep -Fq 'lua evaluation failed' "$TMPDIR/eval-error.out"

        MONITOR_TOPOLOGY_HYPRCTL="$bin/hyprctl" \
            MONITORS="$TMPDIR/monitors.json" \
            HYPRCTL_CALLS="$calls" \
            XDG_STATE_HOME="$state" \
            "$monitorTopology" save
        jq -e '
          .version == 1
          and (.layouts | length == 1)
          and (.layouts[0].monitors | any(.identity.model == "Bottom Panel" and .refresh == 359.979 and .x == 0 and .y == 1440 and .primary))
          and (.layouts[0].monitors | any(.identity.model == "Top Panel" and .refresh == 179.999 and .x == 0 and .y == 0 and (.primary | not)))
        ' "$state/monitor-topologies/layouts.json" >/dev/null
        test "$(stat -c %a "$state/monitor-topologies")" = 700
        test "$(stat -c %a "$state/monitor-topologies/layouts.json")" = 600
        test -z "$(find "$state/monitor-topologies" -name '.layouts.json.*' -print -quit)"

        # At startup the watcher must not overwrite a matching stored profile
        # with compositor defaults. Hyprland's monitor.added event owns restore.
        cp "$TMPDIR/restorable-layouts.json" "$state/monitor-topologies/layouts.json"
        : > "$calls"
        MONITOR_TOPOLOGY_HYPRCTL="$bin/hyprctl" \
            MONITOR_TOPOLOGY_POLL_SECONDS=0.05 \
            MONITOR_TOPOLOGY_SETTLE_SECONDS=0.05 \
            MONITORS="$TMPDIR/monitors.json" \
            HYPRCTL_CALLS="$calls" \
            XDG_STATE_HOME="$state" \
            "$monitorTopology" watch > "$TMPDIR/watch.log" 2>&1 &
        watch_pid=$!
        trap 'kill "$watch_pid" 2>/dev/null || true' EXIT
        sleep 0.2
        test ! -s "$calls"
        jq -e '
          .layouts[0].monitors
          | any(.identity.model == "Bottom Panel" and .refresh == 359.98 and .x == 0 and .y == 1440 and .primary)
          and any(.identity.model == "Top Panel" and .refresh == 180 and .x == 0 and .y == 0 and (.primary | not))
        ' "$state/monitor-topologies/layouts.json" >/dev/null

        jq 'map(if .model == "Bottom Panel" then .x = 123 else . end)' \
            "$TMPDIR/monitors.json" > "$TMPDIR/monitors.next"
        mv "$TMPDIR/monitors.next" "$TMPDIR/monitors.json"

        attempts=0
        until jq -e '
          .layouts[0].monitors
          | any(.identity.model == "Bottom Panel" and .x == 123 and .refresh == 359.979 and .primary)
        ' "$state/monitor-topologies/layouts.json" >/dev/null; do
            if ! kill -0 "$watch_pid" 2>/dev/null; then
                cat "$TMPDIR/watch.log" >&2
                exit 1
            fi
            attempts=$((attempts + 1))
            if [ "$attempts" -ge 100 ]; then
                cat "$TMPDIR/watch.log" >&2
                cat "$state/monitor-topologies/layouts.json" >&2
                exit 1
            fi
            sleep 0.05
        done

        kill "$watch_pid"
        wait "$watch_pid" 2>/dev/null || true
        trap - EXIT

        cat > "$TMPDIR/dynamic-monitor.lua" <<'LUA'
        hl.monitor({ output = "DP-4", mode = "2560x1440@180", position = "0x0", scale = 1, transform = 0 })
        hl.bind("SUPER + P", hl.dsp.focus({ monitor = "DP-4" }))
        LUA
        verify_runtime="$TMPDIR/verify-runtime"
        mkdir -m 700 "$verify_runtime"
        XDG_RUNTIME_DIR="$verify_runtime" \
            ${pkgs.hyprland}/bin/Hyprland --verify-config --config "$TMPDIR/dynamic-monitor.lua"

        touch "$out"
    ''
