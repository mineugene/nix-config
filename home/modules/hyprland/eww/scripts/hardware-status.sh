#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if (( $# != 0 )); then
    printf 'usage: eww-hardware-status\n' >&2
    exit 64
fi

interval=${EWW_HARDWARE_INTERVAL:-2}
display_refresh_cycles=5
proc_root=${EWW_HARDWARE_PROC_ROOT:-/proc}
sys_root=${EWW_HARDWARE_SYS_ROOT:-/sys}

read_cpu() {
    local -a fields

    read -r -a fields < "$proc_root/stat"
    if [[ ${fields[0]-} != cpu ]]; then
        return 1
    fi

    cpu_idle=$(( ${fields[4]:-0} + ${fields[5]:-0} ))
    cpu_total=$((
        ${fields[1]:-0} + ${fields[2]:-0} + ${fields[3]:-0} + cpu_idle +
        ${fields[6]:-0} + ${fields[7]:-0} + ${fields[8]:-0}
    ))
}

read_memory() {
    awk '
        $1 == "MemTotal:" { total = $2 }
        $1 == "MemAvailable:" { available = $2; found_available = 1 }
        END {
            if (total > 0 && found_available) {
                used = total - available
                printf "%.1f %.2f %.2f\n", 100 * used / total, used / 1048576, total / 1048576
            } else {
                print "null null null"
            }
        }
    ' "$proc_root/meminfo"
}

read_cpu_temp_millic() {
    local hwmon input label name value

    for hwmon in "$sys_root"/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        read -r name < "$hwmon/name" || continue
        case "$name" in
            coretemp | k10temp | zenpower | cpu_thermal | x86_pkg_temp) ;;
            *) continue ;;
        esac

        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            label=
            if [[ -r "${input%_input}_label" ]]; then
                read -r label < "${input%_input}_label" || continue
            fi
            case "${label,,}" in
                *package* | *tctl* | *tdie* | *cpu*) ;;
                *) continue ;;
            esac
            read -r value < "$input" || continue
            printf '%s\n' "$value"
            return
        done
    done
}

read_cpu_frequency_khz() {
    local frequency_file value

    for frequency_file in \
        "$sys_root/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" \
        "$sys_root/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"; do
        [[ -r "$frequency_file" ]] || continue
        read -r value < "$frequency_file" || continue
        printf '%s\n' "$value"
        return
    done
}

read_display() {
    local automatic_hdr automatic_hdr_output hyprctl monitors

    display='{"name":null,"width":null,"height":null,"refresh_hz":null,"bit_depth":null,"color_management_mode":null,"automatic_hdr":null,"vrr":null}'
    hyprctl=${EWW_HARDWARE_HYPRCTL:-hyprctl}
    if ! command -v "$hyprctl" >/dev/null 2>&1; then
        return
    fi
    if ! monitors=$(timeout 1 "$hyprctl" monitors -j 2>/dev/null); then
        return
    fi

    automatic_hdr=null
    if automatic_hdr_output=$(timeout 1 "$hyprctl" getoption render:cm_auto_hdr -j 2>/dev/null); then
        automatic_hdr=$(printf '%s\n' "$automatic_hdr_output" | jq -cer '.int // null' 2>/dev/null || printf 'null\n')
    fi

    display=$(printf '%s\n' "$monitors" | jq -cer --argjson automatic_hdr "$automatic_hdr" '
        (first(.[] | select(.focused == true)) // first(.[] | select(.disabled != true)) // {})
        | {
            name: (.name // null),
            width: (.width // null),
            height: (.height // null),
            refresh_hz: (.refreshRate // .refresh_rate // null),
            bit_depth: (.bitdepth // .bitDepth // null),
            color_management_mode: (.colorManagementPreset // .color_management_mode // .cm // null),
            automatic_hdr: $automatic_hdr,
            vrr: (.vrr // null)
        }
    ' 2>/dev/null) || return
}

read_gpu() {
    local nvidia_smi output
    local -a fields=()

    gpu_index=
    gpu_usage=
    gpu_vram_used_mib=
    gpu_vram_total_mib=
    gpu_temp_c=
    gpu_power_w=

    # The active NixOS driver supplies nvidia-smi; packaging another copy in
    # Home Manager could mismatch that driver.
    if ! nvidia_smi=$(command -v nvidia-smi); then
        return
    fi
    if ! output=$(timeout 1 "$nvidia_smi" \
        --query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
        --format=csv,noheader,nounits 2>/dev/null); then
        return
    fi

    # Prefer the lowest-index display-active GPU. If none reports active,
    # fall back to the lowest index instead of depending on output order.
    mapfile -t fields < <(
        printf '%s\n' "$output" | awk -F ',' '
            function trim(value) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                return value
            }
            function is_active(value) {
                value = tolower(value)
                return value == "enabled" || value == "yes" || value == "active"
            }
            {
                for (field = 1; field <= 7; field++) {
                    row[field] = trim($field)
                }
                if (row[1] !~ /^[0-9]+$/) {
                    next
                }
                index_number = row[1] + 0
                if (!have_fallback || index_number < fallback_index) {
                    have_fallback = 1
                    fallback_index = index_number
                    for (field = 1; field <= 7; field++) {
                        fallback[field] = row[field]
                    }
                }
                if (is_active(row[2]) && (!have_active || index_number < active_index)) {
                    have_active = 1
                    active_index = index_number
                    for (field = 1; field <= 7; field++) {
                        active[field] = row[field]
                    }
                }
            }
            END {
                if (!have_active && !have_fallback) {
                    exit
                }
                for (field = 1; field <= 7; field++) {
                    print have_active ? active[field] : fallback[field]
                }
            }
        '
    )

    gpu_index=${fields[0]-}
    gpu_usage=${fields[2]-}
    gpu_vram_used_mib=${fields[3]-}
    gpu_vram_total_mib=${fields[4]-}
    gpu_temp_c=${fields[5]-}
    gpu_power_w=${fields[6]-}
}

read_cpu
previous_total=$cpu_total
previous_idle=$cpu_idle
read_display
display_refresh_cycle=0
while true; do
    sleep "$interval"
    read_cpu

    cpu_usage=$(awk \
        -v total_delta="$(( cpu_total - previous_total ))" \
        -v idle_delta="$(( cpu_idle - previous_idle ))" \
        'BEGIN {
            if (total_delta <= 0) {
                print "null"
            } else {
                printf "%.1f", 100 * (total_delta - idle_delta) / total_delta
            }
        }')

    cpu_load1=
    if [[ -r "$proc_root/loadavg" ]]; then
        read -r cpu_load1 _ < "$proc_root/loadavg" || cpu_load1=
    fi
    uptime_seconds=
    if [[ -r "$proc_root/uptime" ]]; then
        read -r uptime_seconds _ < "$proc_root/uptime" || uptime_seconds=
        uptime_seconds=${uptime_seconds%%.*}
    fi
    cpu_temp_millic=$(read_cpu_temp_millic)
    cpu_frequency_khz=$(read_cpu_frequency_khz)
    read -r memory_usage memory_used_gib memory_total_gib < <(read_memory)
    read_gpu
    display_refresh_cycle=$((display_refresh_cycle + 1))
    if (( display_refresh_cycle >= display_refresh_cycles )); then
        read_display
        display_refresh_cycle=0
    fi

    jq -cn \
        --argjson cpu_usage "$cpu_usage" \
        --arg cpu_temp_millic "$cpu_temp_millic" \
        --arg cpu_load1 "$cpu_load1" \
        --arg cpu_frequency_khz "$cpu_frequency_khz" \
        --arg gpu_index "$gpu_index" \
        --arg gpu_usage "$gpu_usage" \
        --arg gpu_vram_used_mib "$gpu_vram_used_mib" \
        --arg gpu_vram_total_mib "$gpu_vram_total_mib" \
        --arg gpu_temp_c "$gpu_temp_c" \
        --arg gpu_power_w "$gpu_power_w" \
        --argjson memory_usage "$memory_usage" \
        --argjson memory_used_gib "$memory_used_gib" \
        --argjson memory_total_gib "$memory_total_gib" \
        --arg uptime_seconds "$uptime_seconds" \
        --argjson display "$display" \
        '
            def number_or_null:
                if . == "" or . == "N/A" or . == "[N/A]" then null
                else try tonumber catch null
                end;
            def scaled_or_null($scale):
                number_or_null | if . == null then null else . / $scale end;
            {
                cpu: {
                    usage: $cpu_usage,
                    temp_c: ($cpu_temp_millic | scaled_or_null(1000)),
                    load1: ($cpu_load1 | number_or_null),
                    frequency_mhz: ($cpu_frequency_khz | scaled_or_null(1000))
                },
                gpu: {
                    index: ($gpu_index | number_or_null),
                    usage: ($gpu_usage | number_or_null),
                    vram_used_mib: ($gpu_vram_used_mib | number_or_null),
                    vram_total_mib: ($gpu_vram_total_mib | number_or_null),
                    temp_c: ($gpu_temp_c | number_or_null),
                    power_w: ($gpu_power_w | number_or_null)
                },
                memory: {
                    usage: $memory_usage,
                    used_gib: $memory_used_gib,
                    total_gib: $memory_total_gib
                },
                display: $display,
                uptime_seconds: ($uptime_seconds | number_or_null)
            }
        '
    previous_total=$cpu_total
    previous_idle=$cpu_idle
done
