#!/bin/sh
set -eu
export LC_ALL=C

sys_root=${SHELL_POWER_SYS_ROOT:-/sys}
interval=${SHELL_POWER_INTERVAL:-2}
busctl_command=${SHELL_POWER_BUSCTL:-busctl}

ppd_service=net.hadess.PowerProfiles
ppd_path=/net/hadess/PowerProfiles
ppd_interface=net.hadess.PowerProfiles
upower_service=org.freedesktop.UPower
upower_path=/org/freedesktop/UPower/devices/DisplayDevice
upower_interface=org.freedesktop.UPower.Device

usage() {
    printf 'usage: shell-power-status [set <profile>]\n' >&2
}

# Strip the leading type token and the quotes from a `busctl get-property` line.
property_value() {
    awk 'NR == 1 { sub(/^[^ ]+ /, ""); gsub(/"/, ""); print }'
}

set_profile() {
    case $1 in
        power-saver | balanced | performance) ;;
        *)
            printf 'shell-power-status: unknown profile: %s\n' "$1" >&2
            exit 64
            ;;
    esac
    "$busctl_command" --system set-property \
        "$ppd_service" "$ppd_path" "$ppd_interface" ActiveProfile s "$1"
}

# power-profiles-daemon is authoritative when it answers; the empty answer of a
# stopped or absent daemon leaves the profile cell hidden at runtime.
read_profile() {
    profile_available=false
    profile_active=
    profile_inhibited=false
    profile_degraded=false

    command -v "$busctl_command" >/dev/null 2>&1 || return 0

    active=$(
        "$busctl_command" --system get-property \
            "$ppd_service" "$ppd_path" "$ppd_interface" ActiveProfile 2>/dev/null |
            property_value
    ) || active=
    [ -n "$active" ] || return 0

    profile_available=true
    profile_active=$active

    inhibited=$(
        "$busctl_command" --system get-property \
            "$ppd_service" "$ppd_path" "$ppd_interface" PerformanceInhibited 2>/dev/null |
            property_value
    ) || inhibited=
    [ -z "$inhibited" ] || profile_inhibited=true

    degraded=$(
        "$busctl_command" --system get-property \
            "$ppd_service" "$ppd_path" "$ppd_interface" PerformanceDegraded 2>/dev/null |
            property_value
    ) || degraded=
    if [ -n "$degraded" ]; then
        profile_degraded=true
    fi

    return 0
}

add() {
    # $1 current, $2 addend; both must be non-negative integers.
    if [ -n "$2" ]; then
        printf '%s' "$(( $1 + $2 ))"
    else
        printf '%s' "$1"
    fi
}

# The kernel exposes charge as either energy (µWh) or charge (µAh); capacity is
# the simplest percent when present. Time is the matching energy or charge over
# the matching power or current.
read_battery() {
    battery_present=false
    battery_percent=
    battery_status=unknown
    battery_time_s=
    battery_warning=
    battery_devices=

    capacity_sum=0
    capacity_count=0
    energy_now_total=0
    energy_full_total=0
    charge_now_total=0
    charge_full_total=0
    power_now_total=0
    current_now_total=0
    any_charging=false
    any_discharging=false
    any_full=false
    any_not_charging=false

    for dir in "$sys_root"/class/power_supply/*; do
        [ -d "$dir" ] || continue
        supply_type=
        if [ -r "$dir/type" ]; then
            read -r supply_type < "$dir/type" || supply_type=
        fi
        [ "$supply_type" = Battery ] || continue

        battery_present=true
        name=$(basename "$dir")

        supply_status=
        if [ -r "$dir/status" ]; then
            read -r supply_status < "$dir/status" || supply_status=
        fi
        case $supply_status in
            Charging) any_charging=true ;;
            Discharging) any_discharging=true ;;
            Full) any_full=true ;;
            "Not charging") any_not_charging=true ;;
        esac

        capacity=
        if [ -r "$dir/capacity" ]; then
            read -r capacity < "$dir/capacity" || capacity=
        fi
        if [ -n "$capacity" ]; then
            capacity_sum=$((capacity_sum + capacity))
            capacity_count=$((capacity_count + 1))
        fi

        energy_now=
        if [ -r "$dir/energy_now" ]; then
            read -r energy_now < "$dir/energy_now" || energy_now=
        fi
        energy_full=
        if [ -r "$dir/energy_full" ]; then
            read -r energy_full < "$dir/energy_full" || energy_full=
        fi
        charge_now=
        if [ -r "$dir/charge_now" ]; then
            read -r charge_now < "$dir/charge_now" || charge_now=
        fi
        charge_full=
        if [ -r "$dir/charge_full" ]; then
            read -r charge_full < "$dir/charge_full" || charge_full=
        fi
        power_now=
        if [ -r "$dir/power_now" ]; then
            read -r power_now < "$dir/power_now" || power_now=
        fi
        current_now=
        if [ -r "$dir/current_now" ]; then
            read -r current_now < "$dir/current_now" || current_now=
        fi

        energy_now_total=$(add "$energy_now_total" "$energy_now")
        energy_full_total=$(add "$energy_full_total" "$energy_full")
        charge_now_total=$(add "$charge_now_total" "$charge_now")
        charge_full_total=$(add "$charge_full_total" "$charge_full")
        power_now_total=$(add "$power_now_total" "$power_now")
        current_now_total=$(add "$current_now_total" "$current_now")

        device_percent=
        if [ -n "$capacity" ]; then
            device_percent=$capacity
        elif [ -n "$energy_full" ] && [ "$energy_full" -gt 0 ]; then
            device_percent=$(awk -v n="${energy_now:-0}" -v f="$energy_full" 'BEGIN { printf "%.0f", 100 * n / f }')
        elif [ -n "$charge_full" ] && [ "$charge_full" -gt 0 ]; then
            device_percent=$(awk -v n="${charge_now:-0}" -v f="$charge_full" 'BEGIN { printf "%.0f", 100 * n / f }')
        fi
        case $supply_status in
            Charging) device_status=charging ;;
            Discharging) device_status=discharging ;;
            Full) device_status=full ;;
            "Not charging") device_status=not-charging ;;
            *) device_status=unknown ;;
        esac
        battery_devices="${battery_devices}${name}	${device_percent}	${device_status}
"
    done

    [ "$battery_present" = true ] || return 0

    if [ "$capacity_count" -gt 0 ]; then
        battery_percent=$(awk -v s="$capacity_sum" -v c="$capacity_count" 'BEGIN { printf "%.0f", s / c }')
    elif [ "$energy_full_total" -gt 0 ]; then
        battery_percent=$(awk -v n="$energy_now_total" -v f="$energy_full_total" 'BEGIN { printf "%.0f", 100 * n / f }')
    elif [ "$charge_full_total" -gt 0 ]; then
        battery_percent=$(awk -v n="$charge_now_total" -v f="$charge_full_total" 'BEGIN { printf "%.0f", 100 * n / f }')
    fi

    if [ "$any_discharging" = true ]; then
        battery_status=discharging
    elif [ "$any_charging" = true ]; then
        battery_status=charging
    elif [ "$any_not_charging" = true ]; then
        battery_status=not-charging
    elif [ "$any_full" = true ]; then
        battery_status=full
    fi

    # energy/power and charge/current are both hours, so each needs 3600.
    if [ "$battery_status" = discharging ]; then
        if [ "$power_now_total" -gt 0 ] && [ "$energy_now_total" -gt 0 ]; then
            battery_time_s=$(awk -v e="$energy_now_total" -v p="$power_now_total" 'BEGIN { printf "%.0f", 3600 * e / p }')
        elif [ "$current_now_total" -gt 0 ] && [ "$charge_now_total" -gt 0 ]; then
            battery_time_s=$(awk -v c="$charge_now_total" -v i="$current_now_total" 'BEGIN { printf "%.0f", 3600 * c / i }')
        fi
    elif [ "$battery_status" = charging ]; then
        if [ "$power_now_total" -gt 0 ] && [ "$energy_full_total" -gt "$energy_now_total" ]; then
            battery_time_s=$(awk -v f="$energy_full_total" -v e="$energy_now_total" -v p="$power_now_total" 'BEGIN { printf "%.0f", 3600 * (f - e) / p }')
        elif [ "$current_now_total" -gt 0 ] && [ "$charge_full_total" -gt "$charge_now_total" ]; then
            battery_time_s=$(awk -v f="$charge_full_total" -v c="$charge_now_total" -v i="$current_now_total" 'BEGIN { printf "%.0f", 3600 * (f - c) / i }')
        fi
    fi

    upower_percent=
    upower_time=
    upower_warning=
    if upower_output=$(
        "$busctl_command" --system get-property \
            "$upower_service" "$upower_path" "$upower_interface" \
            Percentage TimeToEmpty TimeToFull WarningLevel 2>/dev/null
    ); then
        upower_percent=$(printf '%s\n' "$upower_output" | awk 'NR == 1 { sub(/^[^ ]+ /, ""); print }')
        time_to_empty=$(printf '%s\n' "$upower_output" | awk 'NR == 2 { sub(/^[^ ]+ /, ""); print }')
        time_to_full=$(printf '%s\n' "$upower_output" | awk 'NR == 3 { sub(/^[^ ]+ /, ""); print }')
        upower_warning=$(printf '%s\n' "$upower_output" | awk 'NR == 4 { sub(/^[^ ]+ /, ""); print }')
        if [ "$battery_status" = discharging ] || [ "$battery_status" = not-charging ]; then
            [ "$time_to_empty" = 0 ] || upower_time=$time_to_empty
        else
            [ "$time_to_full" = 0 ] || upower_time=$time_to_full
        fi
    fi

    if [ -n "$upower_percent" ]; then
        battery_percent=$(awk -v p="$upower_percent" 'BEGIN { printf "%.0f", p }')
    fi
    if [ -n "$upower_time" ]; then
        battery_time_s=$upower_time
    fi
    if [ -n "$upower_warning" ]; then
        battery_warning=$upower_warning
    fi

    return 0
}

emit() {
    read_battery
    read_profile

    jq -cn \
        --argjson battery_present "$battery_present" \
        --arg battery_percent "$battery_percent" \
        --arg battery_status "$battery_status" \
        --arg battery_time_s "$battery_time_s" \
        --arg battery_warning "$battery_warning" \
        --arg battery_devices "$battery_devices" \
        --argjson profile_available "$profile_available" \
        --arg profile_active "$profile_active" \
        --argjson profile_inhibited "$profile_inhibited" \
        --argjson profile_degraded "$profile_degraded" \
        '
            def number_or_null:
                if . == "" or . == "N/A" then null else try tonumber catch null end;
            {
                battery: {
                    present: $battery_present,
                    percent: ($battery_percent | number_or_null),
                    status: $battery_status,
                    time_s: ($battery_time_s | number_or_null),
                    warning: ($battery_warning | number_or_null),
                    devices: (
                        $battery_devices
                        | split("\n")
                        | map(select(length > 0))
                        | map(
                            split("\t") as $fields
                            | {
                                name: $fields[0],
                                percent: ($fields[1] | number_or_null),
                                status: $fields[2]
                            }
                        )
                    )
                },
                profile: {
                    available: $profile_available,
                    active: $profile_active,
                    inhibited: $profile_inhibited,
                    degraded: $profile_degraded
                }
            }
        '
}

case ${1:-} in
    "")
        while true; do
            emit
            sleep "$interval"
        done
        ;;
    set)
        [ "$#" -eq 2 ] || {
            usage
            exit 64
        }
        set_profile "$2"
        ;;
    *)
        usage
        exit 64
        ;;
esac