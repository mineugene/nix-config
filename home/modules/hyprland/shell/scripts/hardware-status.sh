#!/bin/sh
set -eu
export LC_ALL=C

if [ "$#" -ne 0 ]; then
    printf 'usage: shell-hardware-status\n' >&2
    exit 64
fi

interval=${SHELL_HARDWARE_INTERVAL:-2}
proc_root=${SHELL_HARDWARE_PROC_ROOT:-/proc}
sys_root=${SHELL_HARDWARE_SYS_ROOT:-/sys}
df_command=${SHELL_HARDWARE_DF:-df}
nvidia_smi_command=${SHELL_HARDWARE_NVIDIA_SMI:-}
liquidctl_command=${SHELL_HARDWARE_LIQUIDCTL:-liquidctl}
cooling_command=${SHELL_HARDWARE_COOLING_CMD:-}
cpu_power_command=${SHELL_HARDWARE_CPU_POWER_CMD:-}

read_cpu() {
    read -r cpu_label cpu_user cpu_nice cpu_system cpu_idle_field cpu_iowait cpu_irq cpu_softirq cpu_steal _cpu_rest < "$proc_root/stat"
    [ "$cpu_label" = cpu ] || return 1

    cpu_idle=$(( ${cpu_idle_field:-0} + ${cpu_iowait:-0} ))
    cpu_total=$((
        ${cpu_user:-0} + ${cpu_nice:-0} + ${cpu_system:-0} + cpu_idle +
        ${cpu_irq:-0} + ${cpu_softirq:-0} + ${cpu_steal:-0}
    ))
}

read_memory() {
    awk '
        $1 == "MemTotal:" { total = $2 }
        $1 == "MemAvailable:" { available = $2; found_available = 1 }
        $1 == "Cached:" { cached = $2 }
        $1 == "SReclaimable:" { reclaimable = $2 }
        $1 == "SwapTotal:" { swap_total = $2 }
        $1 == "SwapFree:" { swap_free = $2 }
        END {
            if (total > 0 && found_available) {
                used = total - available
                cache = cached + reclaimable
                swap_used = swap_total - swap_free
                swap_usage = swap_total > 0 ? 100 * swap_used / swap_total : 0
                printf "%.1f %.2f %.2f %.2f %.2f %.2f %.2f %.1f\n", \
                    100 * used / total, used / 1048576, total / 1048576, cache / 1048576, \
                    available / 1048576, swap_used / 1048576, swap_total / 1048576, swap_usage
            } else {
                print "null null null null null null null null"
            }
        }
    ' "$proc_root/meminfo"
}

read_cpu_temp_millic() (
    for hwmon in "$sys_root"/class/hwmon/hwmon*; do
        [ -r "$hwmon/name" ] || continue
        read -r name < "$hwmon/name" || continue
        case "$name" in
            coretemp | k10temp | zenpower | cpu_thermal | x86_pkg_temp) ;;
            *) continue
            esac

        for input in "$hwmon"/temp*_input; do
            [ -r "$input" ] || continue
            label=
            if [ -r "${input%_input}_label" ]; then
                read -r label < "${input%_input}_label" || continue
            fi
            label=$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')
            case "$label" in
                *package* | *tctl* | *tdie* | *cpu*) ;;
                *) continue
                esac
            read -r value < "$input" || continue
            printf '%s\n' "$value"
            return
        done
    done
)

read_cpu_frequency_khz() (
    for frequency_file in \
        "$sys_root/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" \
        "$sys_root/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"; do
        [ -r "$frequency_file" ] || continue
        read -r value < "$frequency_file" || continue
        printf '%s\n' "$value"
        return
    done
)

# CPU package power is exposed directly by a few hwmon drivers and, on the
# common case, only as an energy counter that must be differentiated.
read_cpu_power_w_override() (
    [ -n "$cpu_power_command" ] || return 1
    command -v "$cpu_power_command" >/dev/null 2>&1 || return 1
    value=$(timeout 3 "$cpu_power_command" 2>/dev/null) || return 1
    value=$(printf '%s' "$value" | tr -d '[:space:]')
    case "$value" in
        '' | *[!0-9.]*) return 1 ;;
    esac
    printf '%s\n' "$value"
)

read_cpu_power_uw() (
    for hwmon in "$sys_root"/class/hwmon/hwmon*; do
        [ -r "$hwmon/name" ] || continue
        read -r name < "$hwmon/name" || continue
        case "$name" in
            coretemp | k10temp | zenpower | cpu_thermal | x86_pkg_temp) ;;
            *) continue
            esac
        for power_input in "$hwmon"/power*_input "$hwmon"/power*_average; do
            [ -r "$power_input" ] || continue
            read -r value < "$power_input" || continue
            printf '%s\n' "$value"
            return
        done
    done
)

rapl_energy_file() (
    for energy in "$sys_root"/class/powercap/*/energy_uj; do
        [ -r "$energy" ] || continue
        printf '%s\n' "$energy"
        return
    done
)

read_storage_json() {
    "$df_command" -h --output=source,fstype,size,used,pcent,target 2>/dev/null |
        awk '
            function pseudo_type(type) {
                return type == "tmpfs" || type == "devtmpfs" || type == "efivarfs" || \
                    type == "overlay" || type == "squashfs" || type == "autofs" || type == "ramfs" || \
                    type == "proc" || type == "sysfs" || type == "cgroup" || type == "cgroup2" || \
                    type == "securityfs" || type == "debugfs" || type == "tracefs" || type == "bpf" || \
                    type == "pstore" || type == "configfs" || type == "fusectl" || \
                    type == "hugetlbfs" || type == "mqueue" || type == "rpc_pipefs" || \
                    type == "binfmt_misc" || type == "nsfs"
            }
            function pseudo_mount(mount) {
                return mount == "/proc" || mount ~ /^\/proc\// || \
                    mount == "/sys" || mount ~ /^\/sys\// || \
                    mount == "/dev" || mount ~ /^\/dev\// || \
                    mount == "/run" || mount ~ /^\/run\//
            }
            BEGIN { printf "[" }
            NR == 1 { next }
            NF >= 6 {
                if ($1 == "none" || pseudo_type($2) || pseudo_mount($6)) { next }
                percent = $5
                gsub(/%/, "", percent)
                if (percent !~ /^[0-9]+$/) { next }
                target = $6
                for (field = 7; field <= NF; field++) { target = target " " $field }
                gsub(/\\/, "\\\\", target)
                gsub(/"/, "\\\"", target)
                printf "%s{\"mount\":\"%s\",\"percent\":%s,\"used\":\"%s\",\"size\":\"%s\"}", (count++ ? "," : ""), target, percent, $4, $3
            }
            END { printf "]\n" }
        '
}

# The main storage device is the first nvme or SATA drive sensor; a single
# system disk has exactly one.
read_storage_temp_millic() (
    for hwmon in "$sys_root"/class/hwmon/hwmon*; do
        [ -r "$hwmon/name" ] || continue
        read -r name < "$hwmon/name" || continue
        case "$name" in
            nvme | drivetemp) ;;
            *) continue
            esac
        [ -r "$hwmon/temp1_input" ] || continue
        read -r value < "$hwmon/temp1_input" || continue
        printf '%s\n' "$value"
        return
    done
)

read_cooling_liquidctl() {
    command -v "$liquidctl_command" >/dev/null 2>&1 || return 0
    output=$(timeout 3 "$liquidctl_command" status 2>/dev/null) || return 0

    pump=$(printf '%s\n' "$output" | awk '
        /[Pp]ump speed/ && /rpm/ {
            for (field = 1; field <= NF; field++) {
                if ($field ~ /^[0-9]+$/) { print $field; exit }
            }
        }')
    fan=$(printf '%s\n' "$output" | awk '
        /[Ff]an speed/ && /rpm/ {
            for (field = 1; field <= NF; field++) {
                if ($field ~ /^[0-9]+$/) { print $field; exit }
            }
        }')

    [ -n "$pump" ] && cooling_aio_pump=$pump
    [ -n "$fan" ] && cooling_cpu_fan=$fan
}

# A host backend prints `cpu_fan_rpm=<n>` and `aio_pump_rpm=<n>`, one per line,
# when the generic scan cannot name the cooler's sensors.
read_cooling_override() {
    [ -n "$cooling_command" ] || return 1
    command -v "$cooling_command" >/dev/null 2>&1 || return 1
    output=$(timeout 3 "$cooling_command" 2>/dev/null) || return 1
    [ -n "$output" ] || return 1

    fan=$(printf '%s\n' "$output" | awk -F '=' '
        $1 == "cpu_fan_rpm" && $2 ~ /^[0-9]+$/ { print $2; exit }')
    pump=$(printf '%s\n' "$output" | awk -F '=' '
        $1 == "aio_pump_rpm" && $2 ~ /^[0-9]+$/ { print $2; exit }')

    if [ -z "$fan" ] && [ -z "$pump" ]; then
        return 1
    fi
    [ -n "$fan" ] && cooling_cpu_fan=$fan
    [ -n "$pump" ] && cooling_aio_pump=$pump
    return 0
}

read_cooling() {
    cooling_cpu_fan=
    cooling_aio_pump=
    if ! read_cooling_override; then
        for hwmon in "$sys_root"/class/hwmon/hwmon*; do
            for input in "$hwmon"/fan*_input; do
                [ -r "$input" ] || continue
                label=
                if [ -r "${input%_input}_label" ]; then
                    read -r label < "${input%_input}_label" || label=
                fi
                [ -n "$label" ] || continue
                key=$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
                read -r value < "$input" || continue
                case "$key" in
                    *pump* | *aio* | *water*) [ -n "$cooling_aio_pump" ] || cooling_aio_pump=$value ;;
                    *cpu*fan*) [ -n "$cooling_cpu_fan" ] || cooling_cpu_fan=$value ;;
                esac
            done
        done

        # The NZXT and similar AIO drivers expose fan and pump speeds through
        # the kernel hwmon only on newer kernels; where they do not, liquidctl
        # is the userspace interface to the same sensors.
        if [ -z "$cooling_cpu_fan" ] && [ -z "$cooling_aio_pump" ]; then
            read_cooling_liquidctl
        fi
    fi

    if [ -z "$cooling_cpu_fan" ] && [ -z "$cooling_aio_pump" ]; then
        cooling_available=false
    else
        cooling_available=true
    fi
}

read_gpu_nvidia() {
    # The active NixOS driver supplies nvidia-smi; packaging another copy in
    # Home Manager could mismatch that driver. The shell service runs with a
    # deliberate PATH, so also look where a NixOS system profile installs it.
    nvidia_smi=$nvidia_smi_command
    if [ -z "$nvidia_smi" ]; then
        if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia_smi=$(command -v nvidia-smi)
        else
            for candidate in \
                /run/current-system/sw/bin/nvidia-smi \
                /run/wrappers/bin/nvidia-smi \
                /run/opengl-driver/bin/nvidia-smi; do
                [ -x "$candidate" ] || continue
                nvidia_smi=$candidate
                break
            done
        fi
    fi
    [ -n "$nvidia_smi" ] || return 1
    if ! output=$(timeout 1 "$nvidia_smi" \
        --query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
        --format=csv,noheader,nounits 2>/dev/null); then
        return 1
    fi

    # Prefer the lowest-index display-active GPU. If none reports active,
    # fall back to the lowest index instead of depending on output order.
    gpu_fields=$(printf '%s\n' "$output" | awk -F ',' '
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
                    printf "%s%s", (field == 1 ? "" : "|"), (have_active ? active[field] : fallback[field])
                }
                printf "\n"
            }
        ') || return 1

    [ -n "$gpu_fields" ] || return 1

    IFS='|' read -r gpu_index _gpu_display_active gpu_usage gpu_vram_used_mib gpu_vram_total_mib gpu_temp_c gpu_power_w <<EOF
$gpu_fields
EOF
}

read_gpu_amdgpu() {
    for hwmon in "$sys_root"/class/hwmon/hwmon*; do
        [ -r "$hwmon/name" ] || continue
        read -r name < "$hwmon/name" || continue
        [ "$name" = amdgpu ] || continue

        # Usage and VRAM live on the DRM device the hwmon node links to, not
        # on the hwmon node itself; temperature and power stay on hwmon.
        device=$hwmon/device
        gpu_busy=
        gpu_vram_used=
        gpu_vram_total=
        gpu_temp_millic=
        gpu_power_uw=
        if [ -r "$device/gpu_busy_percent" ]; then
            read -r gpu_busy < "$device/gpu_busy_percent" || gpu_busy=
        fi
        if [ -r "$device/mem_info_vram_used" ]; then
            read -r gpu_vram_used < "$device/mem_info_vram_used" || gpu_vram_used=
        fi
        if [ -r "$device/mem_info_vram_total" ]; then
            read -r gpu_vram_total < "$device/mem_info_vram_total" || gpu_vram_total=
        fi
        if [ -r "$hwmon/temp1_input" ]; then
            read -r gpu_temp_millic < "$hwmon/temp1_input" || gpu_temp_millic=
        fi
        for power_input in "$hwmon"/power1_average "$hwmon"/power1_input; do
            [ -r "$power_input" ] || continue
            read -r gpu_power_uw < "$power_input" || gpu_power_uw=
            break
        done

        gpu_index=
        gpu_usage=$gpu_busy
        if [ -n "$gpu_vram_used" ]; then
            gpu_vram_used_mib=$(awk -v bytes="$gpu_vram_used" 'BEGIN { printf "%.0f", bytes / 1048576 }')
        else
            gpu_vram_used_mib=
        fi
        if [ -n "$gpu_vram_total" ]; then
            gpu_vram_total_mib=$(awk -v bytes="$gpu_vram_total" 'BEGIN { printf "%.0f", bytes / 1048576 }')
        else
            gpu_vram_total_mib=
        fi
        if [ -n "$gpu_temp_millic" ]; then
            gpu_temp_c=$(awk -v millic="$gpu_temp_millic" 'BEGIN { printf "%.1f", millic / 1000 }')
        else
            gpu_temp_c=
        fi
        if [ -n "$gpu_power_uw" ]; then
            gpu_power_w=$(awk -v microw="$gpu_power_uw" 'BEGIN { printf "%.2f", microw / 1000000 }')
        else
            gpu_power_w=
        fi
        return 0
    done
    return 1
}

read_gpu() {
    gpu_present=false
    gpu_index=
    gpu_usage=
    gpu_vram_used_mib=
    gpu_vram_total_mib=
    gpu_temp_c=
    gpu_power_w=

    if read_gpu_nvidia; then
        gpu_present=true
        return 0
    fi
    if read_gpu_amdgpu; then
        gpu_present=true
        return 0
    fi

    # An integrated GPU without a hwmon driver still counts as a GPU; the
    # section stays visible with empty readings rather than disappearing.
    for card in "$sys_root"/class/drm/card[0-9]*; do
        [ -e "$card/device" ] || continue
        gpu_present=true
        return 0
    done
}

rapl_energy_path=$(rapl_energy_file) || rapl_energy_path=
previous_rapl=
if [ -n "$rapl_energy_path" ] && [ -r "$rapl_energy_path" ]; then
    read -r previous_rapl < "$rapl_energy_path" || previous_rapl=
fi

read_cpu
previous_total=$cpu_total
previous_idle=$cpu_idle
cpu_frequency_max_khz=0
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
    cpu_load5=
    cpu_load15=
    if [ -r "$proc_root/loadavg" ]; then
        read -r cpu_load1 cpu_load5 cpu_load15 _ < "$proc_root/loadavg" || cpu_load1=
    fi
    uptime_seconds=
    if [ -r "$proc_root/uptime" ]; then
        read -r uptime_seconds _ < "$proc_root/uptime" || uptime_seconds=
        uptime_seconds=${uptime_seconds%%.*}
    fi
    cpu_temp_millic=$(read_cpu_temp_millic)
    cpu_frequency_khz=$(read_cpu_frequency_khz)
    if [ -n "$cpu_frequency_khz" ] && [ "$cpu_frequency_khz" -gt "$cpu_frequency_max_khz" ]; then
        cpu_frequency_max_khz=$cpu_frequency_khz
    fi

    if cpu_power_override=$(read_cpu_power_w_override); then
        cpu_power_w=$cpu_power_override
    else
        cpu_power_uw=$(read_cpu_power_uw) || cpu_power_uw=
        if [ -n "$cpu_power_uw" ]; then
            cpu_power_w=$(awk -v microw="$cpu_power_uw" 'BEGIN { printf "%.2f", microw / 1000000 }')
        else
            cpu_power_w=
            if [ -n "$rapl_energy_path" ] && [ -r "$rapl_energy_path" ]; then
                rapl_now=
                read -r rapl_now < "$rapl_energy_path" || rapl_now=
                if [ -n "$previous_rapl" ] && [ -n "$rapl_now" ] && [ "$rapl_now" -ge "$previous_rapl" ]; then
                    cpu_power_w=$(awk -v delta="$(( rapl_now - previous_rapl ))" -v seconds="$interval" \
                        'BEGIN { if (seconds > 0) printf "%.2f", delta / 1000000 / seconds }')
                fi
                previous_rapl=$rapl_now
            fi
        fi
    fi

    memory_values=$(read_memory)
    read -r memory_usage memory_used_gib memory_total_gib memory_cache_gib \
        memory_available_gib memory_swap_used_gib memory_swap_total_gib memory_swap_usage <<EOF
$memory_values
EOF
    storage_devices=$(read_storage_json)
    storage_temp_millic=$(read_storage_temp_millic)
    read_cooling
    read_gpu

    jq -cn \
        --argjson cpu_usage "$cpu_usage" \
        --arg cpu_temp_millic "$cpu_temp_millic" \
        --arg cpu_load1 "$cpu_load1" \
        --arg cpu_load5 "$cpu_load5" \
        --arg cpu_load15 "$cpu_load15" \
        --arg cpu_frequency_khz "$cpu_frequency_khz" \
        --arg cpu_frequency_max_khz "$cpu_frequency_max_khz" \
        --arg cpu_power_w "$cpu_power_w" \
        --argjson gpu_present "$gpu_present" \
        --arg gpu_index "$gpu_index" \
        --arg gpu_usage "$gpu_usage" \
        --arg gpu_vram_used_mib "$gpu_vram_used_mib" \
        --arg gpu_vram_total_mib "$gpu_vram_total_mib" \
        --arg gpu_temp_c "$gpu_temp_c" \
        --arg gpu_power_w "$gpu_power_w" \
        --argjson memory_usage "$memory_usage" \
        --argjson memory_used_gib "$memory_used_gib" \
        --argjson memory_total_gib "$memory_total_gib" \
        --argjson memory_cache_gib "$memory_cache_gib" \
        --argjson memory_available_gib "$memory_available_gib" \
        --argjson memory_swap_used_gib "$memory_swap_used_gib" \
        --argjson memory_swap_total_gib "$memory_swap_total_gib" \
        --argjson memory_swap_usage "$memory_swap_usage" \
        --argjson storage_devices "$storage_devices" \
        --arg storage_temp_millic "$storage_temp_millic" \
        --argjson cooling_available "$cooling_available" \
        --arg cooling_cpu_fan "$cooling_cpu_fan" \
        --arg cooling_aio_pump "$cooling_aio_pump" \
        --arg uptime_seconds "$uptime_seconds" \
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
                    load5: ($cpu_load5 | number_or_null),
                    load15: ($cpu_load15 | number_or_null),
                    frequency_mhz: ($cpu_frequency_khz | scaled_or_null(1000)),
                    frequency_max_mhz: ($cpu_frequency_max_khz | scaled_or_null(1000)),
                    power_w: ($cpu_power_w | number_or_null)
                },
                gpu: {
                    present: $gpu_present,
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
                    total_gib: $memory_total_gib,
                    cache_gib: $memory_cache_gib,
                    available_gib: $memory_available_gib,
                    swap_used_gib: $memory_swap_used_gib,
                    swap_total_gib: $memory_swap_total_gib,
                    swap_usage: $memory_swap_usage
                },
                storage: {
                    devices: $storage_devices,
                    temp_c: ($storage_temp_millic | scaled_or_null(1000))
                },
                cooling: {
                    available: $cooling_available,
                    cpu_fan_rpm: ($cooling_cpu_fan | number_or_null),
                    aio_pump_rpm: ($cooling_aio_pump | number_or_null)
                },
                uptime_seconds: ($uptime_seconds | number_or_null)
            }
        '
    previous_total=$cpu_total
    previous_idle=$cpu_idle
done