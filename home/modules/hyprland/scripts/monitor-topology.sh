#!/bin/sh
set -eu

state_home=${XDG_STATE_HOME:-${HOME:?HOME must be set}/.local/state}
layouts_file=$state_home/monitor-topologies/layouts.json
hyprctl=${MONITOR_TOPOLOGY_HYPRCTL:-hyprctl}

save_layout() {
    preserve_primary=${1:-false}
    monitors=$("$hyprctl" -j monitors all)
    layout=$(printf '%s\n' "$monitors" | jq -c '
        def identity:
            {
                make: (.make // ""),
                model: (.model // ""),
                serial: (.serial // "")
            }
            + if (.serial // "") == "" then
                { description: (.description // "") }
              else
                {}
              end;

        [.[] | select(.disabled != true)] as $connected
        | if ($connected | length) == 0 then
            error("cannot save a topology without active monitors")
          else
            {
                topology: (
                    $connected
                    | map(identity)
                    | sort_by(.make, .model, .serial, (.description // ""))
                ),
                monitors: (
                    $connected
                    | map({
                        identity: (identity),
                        width: .width,
                        height: .height,
                        refresh: .refreshRate,
                        x: .x,
                        y: .y,
                        scale: .scale,
                        transform: .transform,
                        primary: (.focused // false)
                    })
                )
            }
          end
    ')

    mkdir -p -- "$state_home/monitor-topologies"
    chmod 700 "$state_home/monitor-topologies"
    umask 077
    temporary=$(mktemp "$state_home/monitor-topologies/.layouts.json.XXXXXX")
    trap 'rm -f "$temporary"' 0 HUP INT TERM

    if [ -f "$layouts_file" ]; then
        jq --argjson layout "$layout" --argjson preservePrimary "$preserve_primary" '
            def sorted_topology:
                sort_by(.make, .model, .serial, (.description // ""));

            if .version != 1 then
                error("unsupported monitor topology state version")
            else
                (
                    first(
                        (.layouts // [])[]
                        | select(
                            (.topology | sorted_topology)
                            == ($layout.topology | sorted_topology)
                        )
                    ) // null
                ) as $previous
                | (
                    if $preservePrimary and $previous != null then
                        (
                            first(
                                $previous.monitors[]
                                | select(.primary == true)
                                | .identity
                            ) // null
                        ) as $primary
                        | if $primary == null then
                            $layout
                          else
                            $layout
                            | .monitors |= map(.primary = (.identity == $primary))
                          end
                    else
                        $layout
                    end
                ) as $next
                | .layouts = (
                    [
                        (.layouts // [])[]
                        | select(
                            (.topology | sorted_topology)
                            != ($next.topology | sorted_topology)
                        )
                    ]
                    + [$next]
                )
            end
        ' "$layouts_file" > "$temporary"
    else
        jq -n --argjson layout "$layout" '{ version: 1, layouts: [$layout] }' > "$temporary"
    fi

    chmod 600 "$temporary"
    mv -f -- "$temporary" "$layouts_file"
    trap - 0 HUP INT TERM
}

eval_lua() {
    result=$("$hyprctl" eval "$1")
    if [ "$result" != ok ]; then
        printf 'monitor-topology: Hyprland Lua evaluation failed: %s\n' "$result" >&2
        return 1
    fi
}

apply_layout() {
    [ -f "$layouts_file" ] || return 0

    monitors=$("$hyprctl" -j monitors all)

    commands=$(jq -r --argjson connected "$monitors" '
        def identity:
            {
                make: (.make // ""),
                model: (.model // ""),
                serial: (.serial // "")
            }
            + if (.serial // "") == "" then
                { description: (.description // "") }
              else
                {}
              end;
        def topology:
            map(select(.disabled != true) | identity)
            | sort_by(.make, .model, .serial, (.description // ""));
        def normalized_topology:
            map(identity)
            | sort_by(.make, .model, .serial, (.description // ""));

        ($connected | topology) as $topology
        | first(
            .layouts[]
            | select((.topology | normalized_topology) == $topology)
        ) as $layout
        | (
            $layout.monitors[]
            | . as $saved
            | first(
                $connected[]
                | select(.disabled != true)
                | select(identity == ($saved.identity | identity))
            )
            | [
                "monitor",
                (
                    "hl.monitor({ output = "
                    + (.name | tojson)
                    + ", mode = "
                    + (
                        (($saved.width | tostring)
                        + "x"
                        + ($saved.height | tostring)
                        + "@"
                        + ($saved.refresh | tostring))
                        | tojson
                    )
                    + ", position = "
                    + (
                        (($saved.x | tostring) + "x" + ($saved.y | tostring))
                        | tojson
                    )
                    + ", scale = "
                    + ($saved.scale | tojson)
                    + ", transform = "
                    + ($saved.transform | tojson)
                    + " })"
                )
            ]
        )
        | @tsv
    ' "$layouts_file")

    [ -n "$commands" ] || return 1

    while IFS="$(printf '\t')" read -r kind expression; do
        case $kind in
            monitor)
                eval_lua "$expression" || return 2
                ;;
        esac
    done <<EOF
$commands
EOF
}

focus_primary() {
    [ -f "$layouts_file" ] || return 0

    monitors=$("$hyprctl" -j monitors all)
    command=$(jq -r --argjson connected "$monitors" '
        def identity:
            {
                make: (.make // ""),
                model: (.model // ""),
                serial: (.serial // "")
            }
            + if (.serial // "") == "" then
                { description: (.description // "") }
              else
                {}
              end;
        def topology:
            map(select(.disabled != true) | identity)
            | sort_by(.make, .model, .serial, (.description // ""));
        def normalized_topology:
            map(identity)
            | sort_by(.make, .model, .serial, (.description // ""));
        def matches($saved):
            .width == $saved.width
            and .height == $saved.height
            and ((.refreshRate - $saved.refresh) | abs) < 0.1
            and .x == $saved.x
            and .y == $saved.y
            and .scale == $saved.scale
            and .transform == $saved.transform;

        ($connected | topology) as $topology
        | first(
            .layouts[]
            | select((.topology | normalized_topology) == $topology)
        ) as $layout
        | [
            $layout.monitors[] as $saved
            | (first(
                $connected[]
                | select(.disabled != true)
                | select(identity == ($saved.identity | identity))
            ) // null) as $current
            | $current != null and ($current | matches($saved))
          ]
        | all
        | select(.)
        | first($layout.monitors[] | select(.primary == true)) as $primary
        | first(
            $connected[]
            | select(.disabled != true)
            | select(identity == ($primary.identity | identity))
        )
        | "hl.dispatch(hl.dsp.focus({ monitor = " + (.name | tojson) + " }))"
    ' "$layouts_file")

    [ -z "$command" ] || eval_lua "$command"
}

current_snapshot() {
    "$hyprctl" -j monitors all | jq -c '
        def identity:
            {
                make: (.make // ""),
                model: (.model // ""),
                serial: (.serial // "")
            }
            + if (.serial // "") == "" then
                { description: (.description // "") }
              else
                {}
              end;

        [.[] | select(.disabled != true)]
        | {
            topology: (
                map(identity)
                | sort_by(.make, .model, .serial, (.description // ""))
            ),
            layout: (
                map({
                    identity: (identity),
                    width: .width,
                    height: .height,
                    refresh: .refreshRate,
                    x: .x,
                    y: .y,
                    scale: .scale,
                    transform: .transform
                })
                | sort_by(
                    .identity.make,
                    .identity.model,
                    .identity.serial,
                    (.identity.description // "")
                )
            )
        }
    '
}

watch_layouts() {
    poll_seconds=${MONITOR_TOPOLOGY_POLL_SECONDS:-2}
    settle_seconds=${MONITOR_TOPOLOGY_SETTLE_SECONDS:-2}
    initialized=false
    last_topology=
    last_layout=

    while true; do
        if ! snapshot=$(current_snapshot 2>/dev/null); then
            sleep "$poll_seconds"
            continue
        fi

        topology=$(printf '%s\n' "$snapshot" | jq -c '.topology')
        layout=$(printf '%s\n' "$snapshot" | jq -c '.layout')
        if [ "$topology" = '[]' ]; then
            initialized=false
            last_topology=
            last_layout=
            sleep "$poll_seconds"
            continue
        fi

        if [ "$initialized" = false ] || [ "$topology" != "$last_topology" ]; then
            # Hyprland's monitor.added event restores known layouts after the
            # output has completed setup. Record this topology as the baseline
            # so default modes cannot overwrite an existing profile at startup.
            last_topology=$topology
            last_layout=$layout
            initialized=true
        elif [ "$layout" != "$last_layout" ]; then
            sleep "$settle_seconds"
            if ! stable=$(current_snapshot 2>/dev/null); then
                continue
            fi
            stable_topology=$(printf '%s\n' "$stable" | jq -c '.topology')
            stable_layout=$(printf '%s\n' "$stable" | jq -c '.layout')
            if [ "$stable_topology" = "$topology" ] && [ "$stable_layout" = "$layout" ]; then
                save_layout true
                last_topology=$stable_topology
                last_layout=$stable_layout
            fi
        fi

        sleep "$poll_seconds"
    done
}

case ${1-} in
    apply)
        [ "$#" -eq 1 ] || exit 64
        apply_layout
        ;;
    save)
        [ "$#" -eq 1 ] || exit 64
        save_layout
        ;;
    focus-primary)
        [ "$#" -eq 1 ] || exit 64
        focus_primary
        ;;
    watch)
        [ "$#" -eq 1 ] || exit 64
        watch_layouts
        ;;
    *)
        printf 'usage: monitor-topology apply | focus-primary | save | watch\n' >&2
        exit 64
        ;;
esac
