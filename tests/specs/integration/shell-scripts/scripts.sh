#!/bin/sh
set -eu
: "${hardwareStatusCommand:?}" "${out:?}"
: "${waitHelpers:?}"
# shellcheck source=/dev/null
. "$waitHelpers"

mkdir -p "$TMPDIR/bluetooth-bin"
cat > "$TMPDIR/bluetooth-bin/bluetoothctl" <<'SH'
#!/bin/sh
exec sleep 600
SH
chmod +x "$TMPDIR/bluetooth-bin/bluetoothctl"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl" \
    timeout 30 shell-bluetooth status |
    jq -e '.available == false and .powered == false and .adapter == ""' >/dev/null

# A powered adapter with a headset attached: connected and audio are
# separate states because they are drawn with separate glyphs.
mkdir -p "$TMPDIR/bluetooth-sys/class/bluetooth/hci0"
cat > "$TMPDIR/bluetooth-bin/bluetoothctl-powered" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    show) printf 'Powered: yes\n' ;;
    'devices Connected') printf '%s' "${SHELL_BLUETOOTH_DEVICES-Device AA:BB:CC:DD:EE:FF Headset}" ;;
    'info AA:BB:CC:DD:EE:FF') printf 'Icon: %s\n' "${SHELL_BLUETOOTH_ICON:-audio-headset}" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/bluetooth-bin/bluetoothctl-powered"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
    SHELL_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
    shell-bluetooth status |
    jq -e '.available == true and .powered == true and .connected == true and .audio == true and .adapter == "hci0"' >/dev/null
# A stopped service is not a usable control, even when the kernel exposes an
# adapter: the bar hides it instead of offering a toggle that cannot act.
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl" \
    SHELL_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
    shell-bluetooth status |
    jq -e '.available == false and .powered == false and .adapter == "hci0"' >/dev/null
SHELL_BLUETOOTH_ICON=input-mouse \
    SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
    SHELL_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
    shell-bluetooth status |
    jq -e '.connected == true and .audio == false' >/dev/null
SHELL_BLUETOOTH_DEVICES='' \
    SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
    SHELL_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
    shell-bluetooth status |
    jq -e '.powered == true and .connected == false and .audio == false' >/dev/null

# Nearby devices are grouped by pairing state and each group is sorted by
# name; an unpaired device is discovered even while it is connected. The list
# is polled only through the devices subcommand.
mkdir -p "$TMPDIR/bluetooth-devices-bin" "$TMPDIR/bluetooth-devices-state"
cat > "$TMPDIR/bluetooth-devices-bin/bluetoothctl" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    devices) printf '%s\n' 'Device AA:BB:CC:DD:EE:01 Headset' 'Device AA:BB:CC:DD:EE:02 Mouse' 'Device AA:BB:CC:DD:EE:03 Keyboard' 'Device AA:BB:CC:DD:EE:04 Speaker' ;;
    'info AA:BB:CC:DD:EE:01') printf 'Name: Headset\nPaired: yes\nConnected: yes\nRSSI: -40\nIcon: audio-headset\n' ;;
    'info AA:BB:CC:DD:EE:02') printf 'Name: Mouse\nPaired: no\nConnected: no\nRSSI: -70\n' ;;
    'info AA:BB:CC:DD:EE:03') printf 'Name: Keyboard\nPaired: yes\nConnected: no\nIcon: input-keyboard\n' ;;
    'info AA:BB:CC:DD:EE:04') printf 'Name: Speaker\nPaired: no\nConnected: yes\nRSSI: -55\n' ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/bluetoothctl"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-devices-state" \
    shell-bluetooth devices |
    jq -e '
        .scanning == false and (.devices | length) == 4 and
        (.paired_online | length) == 1 and .paired_online[0].address == "AA:BB:CC:DD:EE:01" and
        (.paired_offline | length) == 1 and .paired_offline[0].name == "Keyboard" and
        (.discovered | length) == 2 and .discovered[0].name == "Mouse" and
        .discovered[1].name == "Speaker" and .discovered[1].connected == true and
        .discovered[1].paired == false and (.discovered_top | length) == 2 and
        .devices[0].name == "Headset" and .devices[0].rssi == -40
    ' >/dev/null
# bluetoothctl masks RSSI into hex with the signed value in parentheses. The
# row must read the decimal; a value jq rejects aborts the whole list.
mkdir -p "$TMPDIR/bluetooth-rssi-bin"
cat > "$TMPDIR/bluetooth-rssi-bin/bluetoothctl" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    devices) printf '%s\n' 'Device AA:BB:CC:DD:EE:01 Hex' 'Device AA:BB:CC:DD:EE:02 Plain' ;;
    'info AA:BB:CC:DD:EE:01') printf 'Name: Hex\n\tRSSI: 0xffffffad (-83)\n' ;;
    'info AA:BB:CC:DD:EE:02') printf 'Name: Plain\n\tRSSI: -70\n' ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/bluetooth-rssi-bin/bluetoothctl"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-rssi-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-rssi-state" \
    shell-bluetooth devices |
    jq -e '.devices[0].name == "Hex" and .devices[0].rssi == -83 and .devices[1].rssi == -70' >/dev/null
# A scan marks itself in flight until it finishes.
: > "$TMPDIR/bluetooth-devices-state/scanning"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-devices-state" \
    shell-bluetooth devices |
    jq -e '.scanning == true' >/dev/null
rm -f "$TMPDIR/bluetooth-devices-state/scanning"

# The watch helper does no list work while nothing is scanning, and emits the
# list once, with scanning cleared, for a scan that has finished.
test "$(
    SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/bluetoothctl" \
        SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-devices-state" \
        timeout 3 shell-bluetooth watch 2>/dev/null | wc -l
)" -eq 0
: > "$TMPDIR/bluetooth-devices-state/scanning"
test "$(
    SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/bluetoothctl" \
        SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-devices-state" \
        timeout 3 shell-bluetooth watch 2>/dev/null | wc -l
)" -eq 1
rm -f "$TMPDIR/bluetooth-devices-state/scanning"

# bluetoothctl starts discovery and returns at once unless it is given
# --timeout, and discovery stops when it exits. The scan must pass the timeout
# to the tool rather than wrap it in coreutils timeout, or the scan marker is
# gone before the watcher's tick and the list never refreshes.
cat > "$TMPDIR/bluetooth-devices-bin/scan" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$SHELL_BLUETOOTH_SCAN_LOG"
case $1 in
    --timeout) sleep "$2" ;;
esac
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/scan"
export SHELL_BLUETOOTH_SCAN_LOG="$TMPDIR/bluetooth-scan-args"
: > "$SHELL_BLUETOOTH_SCAN_LOG"
rm -rf "$TMPDIR/bluetooth-scan-state"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/scan" \
    SHELL_BLUETOOTH_SCAN_SECONDS=2 \
    SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-scan-state" \
    shell-bluetooth scan
test "$(cat "$SHELL_BLUETOOTH_SCAN_LOG")" = '--timeout 2 scan on'
sleep 1
test -e "$TMPDIR/bluetooth-scan-state/scanning"
sleep 2
test ! -e "$TMPDIR/bluetooth-scan-state/scanning"

# Broadcasting turns discoverability and pairing on together, marks the state,
# and turns both off again on request.
mkdir -p "$TMPDIR/bluetooth-broadcast-bin"
cat > "$TMPDIR/bluetooth-broadcast-bin/bluetoothctl" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$SHELL_BLUETOOTH_BROADCAST_LOG"
SH
chmod +x "$TMPDIR/bluetooth-broadcast-bin/bluetoothctl"
export SHELL_BLUETOOTH_BROADCAST_LOG="$TMPDIR/bluetooth-broadcast-actions"
broadcast_state="$TMPDIR/bluetooth-broadcast-state"
rm -rf "$broadcast_state"
: > "$SHELL_BLUETOOTH_BROADCAST_LOG"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-broadcast-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$broadcast_state" \
    SHELL_BLUETOOTH_BROADCAST_SECONDS=600 \
    shell-bluetooth broadcast on
test "$(cat "$SHELL_BLUETOOTH_BROADCAST_LOG")" = 'discoverable on
pairable on'
test -e "$broadcast_state/broadcasting"
: > "$SHELL_BLUETOOTH_BROADCAST_LOG"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-broadcast-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$broadcast_state" \
    shell-bluetooth broadcast off
test "$(cat "$SHELL_BLUETOOTH_BROADCAST_LOG")" = 'discoverable off
pairable off'
test ! -e "$broadcast_state/broadcasting"
# The detached watchdog restores the adapter when the close path never runs.
: > "$SHELL_BLUETOOTH_BROADCAST_LOG"
SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-broadcast-bin/bluetoothctl" \
    SHELL_BLUETOOTH_STATE_ROOT="$broadcast_state" \
    SHELL_BLUETOOTH_BROADCAST_SECONDS=1 \
    shell-bluetooth broadcast on
wait_until grep -Fxq 'pairable off' "$SHELL_BLUETOOTH_BROADCAST_LOG"
test ! -e "$broadcast_state/broadcasting"

# The full list is a Rofi menu; the chosen row comes back as an index, so the
# action targets the same numbered entry the inline rows use. The group
# headings are rows too, so their indices sit between the device rows and a
# heading selection carries no address.
cat > "$TMPDIR/bluetooth-devices-bin/rofi" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "${SHELL_BLUETOOTH_PROMPT:-}"
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/rofi"
cat > "$TMPDIR/bluetooth-devices-bin/desktop-theme" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "${SHELL_BLUETOOTH_THEME_MODE:-dark}"
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/desktop-theme"
cat > "$TMPDIR/bluetooth-devices-bin/monitor-topology" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' 'DP-1'
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/monitor-topology"
cat > "$TMPDIR/bluetooth-devices-bin/bluetoothctl-action" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    devices) printf '%s\n' 'Device AA:BB:CC:DD:EE:01 Headset' 'Device AA:BB:CC:DD:EE:02 Mouse' 'Device AA:BB:CC:DD:EE:03 Keyboard' ;;
    'info AA:BB:CC:DD:EE:01') printf 'Name: Headset\nPaired: yes\nConnected: yes\nRSSI: -40\nIcon: audio-headset\n' ;;
    'info AA:BB:CC:DD:EE:02') printf 'Name: Mouse\nPaired: no\nConnected: no\nRSSI: -70\n' ;;
    'info AA:BB:CC:DD:EE:03') printf 'Name: Keyboard\nPaired: yes\nConnected: no\nIcon: input-keyboard\n' ;;
    *) printf '%s\n' "$*" >> "$SHELL_BLUETOOTH_LOG" ;;
  esac
SH
chmod +x "$TMPDIR/bluetooth-devices-bin/bluetoothctl-action"
export SHELL_BLUETOOTH_LOG="$TMPDIR/bluetooth-actions"
run_bluetooth_menu() {
    SHELL_BLUETOOTHCTL="$TMPDIR/bluetooth-devices-bin/bluetoothctl-action" \
        SHELL_BLUETOOTH_DESKTOP_THEME="$TMPDIR/bluetooth-devices-bin/desktop-theme" \
        SHELL_BLUETOOTH_MONITOR_TOPOLOGY="$TMPDIR/bluetooth-devices-bin/monitor-topology" \
        SHELL_BLUETOOTH_ROFI="$TMPDIR/bluetooth-devices-bin/rofi" \
        SHELL_BLUETOOTH_STATE_ROOT="$TMPDIR/bluetooth-devices-state" \
        SHELL_BLUETOOTH_PROMPT="$1" \
        shell-bluetooth menu
}
: > "$SHELL_BLUETOOTH_LOG"
run_bluetooth_menu 0
test ! -s "$SHELL_BLUETOOTH_LOG"
: > "$SHELL_BLUETOOTH_LOG"
run_bluetooth_menu 1
test "$(cat "$SHELL_BLUETOOTH_LOG")" = 'disconnect AA:BB:CC:DD:EE:01'
: > "$SHELL_BLUETOOTH_LOG"
run_bluetooth_menu 3
test "$(cat "$SHELL_BLUETOOTH_LOG")" = 'connect AA:BB:CC:DD:EE:03'
: > "$SHELL_BLUETOOTH_LOG"
run_bluetooth_menu 5
test "$(cat "$SHELL_BLUETOOTH_LOG")" = 'pair AA:BB:CC:DD:EE:02'

mkdir -p "$TMPDIR/hardware-proc"
cat > "$TMPDIR/hardware-proc/meminfo" <<'EOF'
MemTotal:       32768000 kB
MemAvailable:   24576000 kB
MemFree:         1024000 kB
Cached:          2048000 kB
SReclaimable:     512000 kB
SwapTotal:       8388608 kB
SwapFree:        6291456 kB
EOF
printf '3661.90 1200.00\n' > "$TMPDIR/hardware-proc/uptime"
printf '0.72 0.65 0.60 2/1024 42\n' > "$TMPDIR/hardware-proc/loadavg"
printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
mkdir -p \
    "$TMPDIR/hardware-sys/class/hwmon/hwmon0" \
    "$TMPDIR/hardware-sys/class/hwmon/hwmon1" \
    "$TMPDIR/hardware-sys/class/hwmon/hwmon2" \
    "$TMPDIR/hardware-sys/devices/system/cpu/cpu0/cpufreq"
printf 'coretemp\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/name"
printf 'Package id 0\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/temp1_label"
printf '48000\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/temp1_input"
printf '65000000\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon0/power1_input"
printf 'nct6775\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon1/name"
printf 'CPU_FAN\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon1/fan1_label"
printf '1200\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon1/fan1_input"
printf 'AIO_PUMP\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon1/fan2_label"
printf '2100\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon1/fan2_input"
printf 'nvme\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon2/name"
printf '34000\n' > "$TMPDIR/hardware-sys/class/hwmon/hwmon2/temp1_input"
printf '3600000\n' > "$TMPDIR/hardware-sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
mkdir -p "$TMPDIR/hardware-bin"
cat > "$TMPDIR/hardware-bin/nvidia-smi" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$SHELL_NVIDIA_LOG"
cat <<'EOF'
0, Disabled, 88, 1024, 8192, 70, 155.50
1, Enabled, 12, 900, 12288, 43, 35.25
EOF
SH
chmod +x "$TMPDIR/hardware-bin/nvidia-smi"
cat > "$TMPDIR/hardware-bin/liquidctl" <<'SH'
#!/bin/sh
set -eu
cat <<'EOF'
NZXT Kraken 2024 Elite RGB
Liquid temperature    33.8  C
Pump speed            2911  rpm
Pump duty              100  %
Fan speed              970  rpm
Fan duty                46  %
EOF
SH
chmod +x "$TMPDIR/hardware-bin/liquidctl"
cat > "$TMPDIR/hardware-bin/df" <<'SH'
#!/bin/sh
set -eu
cat <<'EOF'
Filesystem     Type      Size  Used Use% Mounted on
/dev/nvme0n1p2 ext4      1.8T   42G   3% /
/dev/sda1      ext4      500G  100G  20% /mnt/data
efivarfs       efivarfs  128K   76K  62% /sys/firmware/efi/efivars
tmpfs          tmpfs      16G     1M   1% /run
none           tmpfs     1.0M      0   0% /run/credentials/systemd-resolved.service
EOF
SH
chmod +x "$TMPDIR/hardware-bin/df"
export SHELL_NVIDIA_LOG="$TMPDIR/nvidia-queries"
has_lines() {
    [ "$(wc -l < "$1")" -ge "$2" ]
}
PATH="$TMPDIR/hardware-bin:$PATH" \
    SHELL_HARDWARE_INTERVAL=1 \
    SHELL_HARDWARE_DF="$TMPDIR/hardware-bin/df" \
    SHELL_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
    SHELL_HARDWARE_SYS_ROOT="$TMPDIR/hardware-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/hardware-status" &
hardware_pid=$!
wait_until has_lines "$TMPDIR/hardware-status" 1
# Advance the counters only once the first sample has read them, so the
# second sample is a known delta.
printf 'cpu  150 0 150 900 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
wait_until has_lines "$TMPDIR/hardware-status" 2
kill "$hardware_pid" >/dev/null 2>&1 || true
wait "$hardware_pid" >/dev/null 2>&1 || true
hardware_line=$(sed -n '2p' "$TMPDIR/hardware-status")
printf '%s\n' "$hardware_line" | jq -e '
    .cpu.usage == 50 and
    .cpu.temp_c == 48 and
    .cpu.load1 == 0.72 and
    .cpu.load5 == 0.65 and
    .cpu.load15 == 0.60 and
    .cpu.frequency_mhz == 3600 and
    .cpu.frequency_max_mhz == 3600 and
    .cpu.power_w == 65 and
    .uptime_seconds == 3661
' >/dev/null
printf '%s\n' "$hardware_line" | jq -e '
    .memory.usage == 25 and
    .memory.used_gib == 7.81 and
    .memory.total_gib == 31.25 and
    .memory.cache_gib == 2.44 and
    .memory.available_gib == 23.44 and
    .memory.swap_used_gib == 2 and
    .memory.swap_total_gib == 8 and
    .memory.swap_usage == 25
' >/dev/null
printf '%s\n' "$hardware_line" | jq -e '
    .gpu.present == true and
    .gpu.index == 1 and
    .gpu.usage == 12 and
    .gpu.vram_used_mib == 900 and
    .gpu.vram_total_mib == 12288 and
    .gpu.temp_c == 43 and
    .gpu.power_w == 35.25
' >/dev/null
printf '%s\n' "$hardware_line" | jq -e '
    (.storage.devices | length) == 2 and
    .storage.devices[0].mount == "/" and
    .storage.devices[0].percent == 3 and
    .storage.devices[0].used == "42G" and
    .storage.devices[0].size == "1.8T" and
    .storage.devices[1].mount == "/mnt/data" and
    .storage.temp_c == 34 and
    .cooling.available == true and
    .cooling.cpu_fan_rpm == 1200 and
    .cooling.aio_pump_rpm == 2100
' >/dev/null
test "$(cat "$SHELL_NVIDIA_LOG")" = '--query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
--query-gpu=index,display_active,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits'

mkdir -p "$TMPDIR/missing-proc" "$TMPDIR/missing-sys" "$TMPDIR/missing-bin"
cp "$TMPDIR/hardware-proc/meminfo" "$TMPDIR/missing-proc/meminfo"
cp "$TMPDIR/hardware-proc/loadavg" "$TMPDIR/missing-proc/loadavg"
cp "$TMPDIR/hardware-proc/uptime" "$TMPDIR/missing-proc/uptime"
printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/missing-proc/stat"
PATH="$TMPDIR/missing-bin" \
    SHELL_HARDWARE_INTERVAL=1 \
    SHELL_HARDWARE_DF=true \
    SHELL_HARDWARE_PROC_ROOT="$TMPDIR/missing-proc" \
    SHELL_HARDWARE_SYS_ROOT="$TMPDIR/missing-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/missing-status" &
missing_hardware_pid=$!
wait_until test -s "$TMPDIR/missing-status"
kill "$missing_hardware_pid" >/dev/null 2>&1 || true
wait "$missing_hardware_pid" >/dev/null 2>&1 || true
missing_line=$(head -n 1 "$TMPDIR/missing-status")
printf '%s\n' "$missing_line" | jq -e '
    .cpu.temp_c == null and
    .cpu.frequency_mhz == null and
    .gpu.present == false and
    .gpu.usage == null and
    .cooling.available == false and
    (.storage.devices | length) == 0 and
    .storage.temp_c == null
' >/dev/null

# No fan labels in hwmon: the AIO pump and fan speeds come from liquidctl.
mkdir -p "$TMPDIR/liquidctl-sys/class/hwmon/hwmon0" \
    "$TMPDIR/liquidctl-sys/devices/system/cpu/cpu0/cpufreq"
printf 'coretemp\n' > "$TMPDIR/liquidctl-sys/class/hwmon/hwmon0/name"
printf 'Package id 0\n' > "$TMPDIR/liquidctl-sys/class/hwmon/hwmon0/temp1_label"
printf '48000\n' > "$TMPDIR/liquidctl-sys/class/hwmon/hwmon0/temp1_input"
printf '3600000\n' > "$TMPDIR/liquidctl-sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
PATH="$TMPDIR/missing-bin" \
    SHELL_HARDWARE_INTERVAL=1 \
    SHELL_HARDWARE_DF=true \
    SHELL_HARDWARE_LIQUIDCTL="$TMPDIR/hardware-bin/liquidctl" \
    SHELL_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
    SHELL_HARDWARE_SYS_ROOT="$TMPDIR/liquidctl-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/liquidctl-status" &
liquidctl_pid=$!
wait_until has_lines "$TMPDIR/liquidctl-status" 1
kill "$liquidctl_pid" >/dev/null 2>&1 || true
wait "$liquidctl_pid" >/dev/null 2>&1 || true
liquidctl_line=$(head -n 1 "$TMPDIR/liquidctl-status")
printf '%s\n' "$liquidctl_line" | jq -e '
    .cooling.available == true and
    .cooling.cpu_fan_rpm == 970 and
    .cooling.aio_pump_rpm == 2911
' >/dev/null

# An AMD GPU reads usage and VRAM from the DRM device behind its hwmon node;
# only temperature and power live on the hwmon node itself.
mkdir -p "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/device" \
    "$TMPDIR/amdgpu-sys/devices/system/cpu/cpu0/cpufreq"
printf 'amdgpu\n' > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/name"
printf '37\n' > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/device/gpu_busy_percent"
printf '%s\n' "$((2048 * 1048576))" > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/device/mem_info_vram_used"
printf '%s\n' "$((8192 * 1048576))" > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/device/mem_info_vram_total"
printf '41000\n' > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/temp1_input"
printf '73000000\n' > "$TMPDIR/amdgpu-sys/class/hwmon/hwmon0/power1_input"
printf '2400000\n' > "$TMPDIR/amdgpu-sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
PATH="$TMPDIR/missing-bin" \
    SHELL_HARDWARE_INTERVAL=1 \
    SHELL_HARDWARE_DF=true \
    SHELL_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
    SHELL_HARDWARE_SYS_ROOT="$TMPDIR/amdgpu-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/amdgpu-status" &
amdgpu_pid=$!
wait_until has_lines "$TMPDIR/amdgpu-status" 1
kill "$amdgpu_pid" >/dev/null 2>&1 || true
wait "$amdgpu_pid" >/dev/null 2>&1 || true
amdgpu_line=$(head -n 1 "$TMPDIR/amdgpu-status")
printf '%s\n' "$amdgpu_line" | jq -e '
    .gpu.present == true and
    .gpu.usage == 37 and
    .gpu.vram_used_mib == 2048 and
    .gpu.vram_total_mib == 8192 and
    .gpu.temp_c == 41 and
    .gpu.power_w == 73
' >/dev/null

# Host backends win over the generic scan, so a machine whose cooler cannot be
# named in hwmon and whose RAPL counter is unreadable can supply both readings.
cat > "$TMPDIR/hardware-bin/cooling-override" <<'SH'
#!/bin/sh
printf 'cpu_fan_rpm=1500\naio_pump_rpm=2800\n'
SH
chmod +x "$TMPDIR/hardware-bin/cooling-override"
cat > "$TMPDIR/hardware-bin/cpu-power-override" <<'SH'
#!/bin/sh
printf '42.5\n'
SH
chmod +x "$TMPDIR/hardware-bin/cpu-power-override"
PATH="$TMPDIR/missing-bin" \
    SHELL_HARDWARE_INTERVAL=1 \
    SHELL_HARDWARE_DF=true \
    SHELL_HARDWARE_COOLING_CMD="$TMPDIR/hardware-bin/cooling-override" \
    SHELL_HARDWARE_CPU_POWER_CMD="$TMPDIR/hardware-bin/cpu-power-override" \
    SHELL_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
    SHELL_HARDWARE_SYS_ROOT="$TMPDIR/hardware-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/override-status" &
override_pid=$!
wait_until has_lines "$TMPDIR/override-status" 1
kill "$override_pid" >/dev/null 2>&1 || true
wait "$override_pid" >/dev/null 2>&1 || true
override_line=$(head -n 1 "$TMPDIR/override-status")
printf '%s\n' "$override_line" | jq -e '
    .cooling.available == true and
    .cooling.cpu_fan_rpm == 1500 and
    .cooling.aio_pump_rpm == 2800 and
    .cpu.power_w == 42.5
' >/dev/null

# wlan0 is wireless and carrying; no ethernet interface exists, which
# is what must hide the Ethernet control on this machine. iwd is stubbed over
# its D-Bus API and systemd-networkd addressing over `ip`.
mkdir -p "$TMPDIR/network-bin" "$TMPDIR/network-sys/class/net/wlan0/statistics" \
    "$TMPDIR/network-sys/class/net/wlan0/wireless" "$TMPDIR/network-state"
printf 'up\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"
printf '1\n' > "$TMPDIR/network-sys/class/net/wlan0/carrier"
printf '0x1003\n' > "$TMPDIR/network-sys/class/net/wlan0/flags"

cat > "$TMPDIR/network-bin/busctl" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    'tree net.connman.iwd')
        printf '%s\n' \
            'net.connman.iwd' \
            '└─/net/connman/iwd' \
            '  └─/net/connman/iwd/0' \
            '    └─/net/connman/iwd/0/1' \
            '      └─/net/connman/iwd/0/1/686f6d65_psk'
        ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Device Name') printf '{"type":"s","data":"wlan0"}\n' ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Device Powered') printf '{"type":"b","data":%s}\n' "${SHELL_NETWORK_POWERED:-true}" ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Station State') printf '{"type":"s","data":"%s"}\n' "${SHELL_NETWORK_STATE:-connected}" ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Station Scanning') printf '{"type":"b","data":%s}\n' "${SHELL_NETWORK_SCANNING:-false}" ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Station ConnectedNetwork') [ "${SHELL_NETWORK_LINKED:-1}" = 1 ] || exit 1; printf '{"type":"o","data":"/net/connman/iwd/0/1/686f6d65_psk"}\n' ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1/686f6d65_psk net.connman.iwd.Network Name') printf '{"type":"s","data":"%s"}\n' "${SHELL_NETWORK_SSID:-Home WiFi}" ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1/686f6d65_psk net.connman.iwd.Network Type') printf '{"type":"s","data":"%s"}\n' "${SHELL_NETWORK_SECURITY:-psk}" ;;
    *'get-property net.connman.iwd /net/connman/iwd/0/1/686f6d65_psk net.connman.iwd.Network KnownNetwork') [ "${SHELL_NETWORK_KNOWN:-1}" = 1 ] || exit 1; printf '{"type":"o","data":"/net/connman/iwd/0/1/686f6d65_psk/known"}\n' ;;
    *'call net.connman.iwd /net/connman/iwd/0/1 net.connman.iwd.Station GetOrderedNetworks') printf '{"type":"a(on)","data":[[["/net/connman/iwd/0/1/686f6d65_psk",%s]]]}\n' "${SHELL_NETWORK_SIGNAL:--5000}" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/network-bin/busctl"

cat > "$TMPDIR/network-bin/ip" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    '-4 -o addr show dev wlan0') printf '%s\n' "2: wlan0    inet ${SHELL_NETWORK_ADDRESS:-192.0.2.10}/24 brd 192.0.2.255 scope global wlan0" ;;
    '-4 route show default dev wlan0') [ "${SHELL_NETWORK_ROUTE:-1}" = 1 ] && printf '%s\n' 'default via 192.0.2.1 dev wlan0' ;;
    '-4 -o addr show dev eno1') printf '%s\n' "3: eno1    inet ${SHELL_NETWORK_ETHERNET_ADDRESS:-198.51.100.5}/24 brd 198.51.100.255 scope global eno1" ;;
    '-4 route show default dev eno1') printf '%s\n' 'default via 198.51.100.1 dev eno1' ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/network-bin/ip"

cat > "$TMPDIR/network-bin/pkexec" <<'SH'
#!/bin/sh
set -eu
exec "$@"
SH
chmod +x "$TMPDIR/network-bin/pkexec"

cat > "$TMPDIR/network-bin/iwctl" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$SHELL_NETWORK_LOG"
SH
chmod +x "$TMPDIR/network-bin/iwctl"

cat > "$TMPDIR/network-bin/rofi" <<'SH'
#!/bin/sh
set -eu
case " $* " in
    *' -password '*) printf '%s\n' "${SHELL_NETWORK_PASSPHRASE:-}" ;;
    *) printf '%s\n' "${SHELL_NETWORK_PROMPT:-}" ;;
esac
SH
chmod +x "$TMPDIR/network-bin/rofi"

cat > "$TMPDIR/network-bin/desktop-theme" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "${SHELL_NETWORK_THEME_MODE:-dark}"
SH
chmod +x "$TMPDIR/network-bin/desktop-theme"

cat > "$TMPDIR/network-bin/monitor-topology" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' 'DP-1'
SH
chmod +x "$TMPDIR/network-bin/monitor-topology"

network_env() {
    SHELL_NETWORK_BUSCTL="${SHELL_NETWORK_BUSCTL:-$TMPDIR/network-bin/busctl}" \
        SHELL_NETWORK_DESKTOP_THEME="${SHELL_NETWORK_DESKTOP_THEME:-$TMPDIR/network-bin/desktop-theme}" \
        SHELL_NETWORK_IP="${SHELL_NETWORK_IP:-$TMPDIR/network-bin/ip}" \
        SHELL_NETWORK_IWCTL="${SHELL_NETWORK_IWCTL:-$TMPDIR/network-bin/iwctl}" \
        SHELL_NETWORK_MONITOR_TOPOLOGY="${SHELL_NETWORK_MONITOR_TOPOLOGY:-$TMPDIR/network-bin/monitor-topology}" \
        SHELL_NETWORK_PKEXEC="${SHELL_NETWORK_PKEXEC:-$TMPDIR/network-bin/pkexec}" \
        SHELL_NETWORK_ROFI="${SHELL_NETWORK_ROFI:-$TMPDIR/network-bin/rofi}" \
        SHELL_NETWORK_SYS_ROOT="${SHELL_NETWORK_SYS_ROOT:-$TMPDIR/network-sys}" \
        SHELL_NETWORK_STATE_ROOT="${SHELL_NETWORK_STATE_ROOT:-$TMPDIR/network-state}" \
        "$@"
}

# The radio toggle is its own action; it must reach iwctl with the requested
# state and reject anything else. pkexec is stubbed to run the target directly.
export SHELL_NETWORK_LOG="$TMPDIR/network-wifi-actions"
: > "$SHELL_NETWORK_LOG"
network_env shell-network-listener wifi on
network_env shell-network-listener wifi off
test "$(cat "$SHELL_NETWORK_LOG")" = 'device wlan0 set-property Powered on
device wlan0 set-property Powered off'
: > "$SHELL_NETWORK_LOG"
if network_env shell-network-listener wifi maybe >/dev/null 2>&1; then
    echo 'shell-network-listener accepted an invalid wifi action' >&2
    exit 1
fi

printf '1048576\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"
printf '524288\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
network_status=$(network_env shell-network-listener status)
printf '%s\n' "$network_status" | jq -e '
    .wifi.available == true and .wifi.state == "connected" and .wifi.connected == true and
    .wifi.internet == true and .wifi.interface == "wlan0" and .wifi.name == "Home WiFi" and
    .wifi.signal == 50 and .wifi.ip == "192.0.2.10/24" and
    .wifi.rx_bytes_per_second == 0 and .wifi.tx_bytes_per_second == 0 and
    .ethernet.available == false and .primary.kind == "wifi"
' >/dev/null
# No default route means no internet even while associated.
SHELL_NETWORK_ROUTE=0 network_env shell-network-listener status |
    jq -e '.wifi.connected == true and .wifi.internet == false' >/dev/null
# A powered-down radio keeps its control and reports it as off.
SHELL_NETWORK_POWERED=false SHELL_NETWORK_STATE=disconnected SHELL_NETWORK_LINKED=0 \
    network_env shell-network-listener status |
    jq -e '.wifi.available == true and .wifi.state == "off" and .wifi.connected == false' >/dev/null
SHELL_NETWORK_STATE=disconnected SHELL_NETWORK_LINKED=0 \
    network_env shell-network-listener status |
    jq -e '.wifi.available == true and .wifi.state == "disconnected" and .wifi.connected == false' >/dev/null
# An unassociated radio is administratively up but carries no signal, so
# operstate is down while the interface is still usable. It is disconnected,
# not unavailable, and its control must stay on the bar.
printf 'down\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"
SHELL_NETWORK_STATE=disconnected SHELL_NETWORK_LINKED=0 \
    network_env shell-network-listener status |
    jq -e '.wifi.available == true and .wifi.state == "disconnected"' >/dev/null
# Clearing IFF_UP is what makes the interface unusable and hides the control.
printf '0x1002\n' > "$TMPDIR/network-sys/class/net/wlan0/flags"
SHELL_NETWORK_STATE=disconnected SHELL_NETWORK_LINKED=0 \
    network_env shell-network-listener status |
    jq -e '.wifi.available == true and .wifi.state == "unavailable"' >/dev/null
printf '0x1003\n' > "$TMPDIR/network-sys/class/net/wlan0/flags"
printf 'up\n' > "$TMPDIR/network-sys/class/net/wlan0/operstate"

# A wired link and a wireless link coexist; wired wins the primary slot.
mkdir -p "$TMPDIR/network-fallback-sys/class/net/eno1" \
    "$TMPDIR/network-fallback-sys/class/net/wlan0/wireless"
printf 'up\n' > "$TMPDIR/network-fallback-sys/class/net/eno1/operstate"
printf '1\n' > "$TMPDIR/network-fallback-sys/class/net/eno1/carrier"
printf 'up\n' > "$TMPDIR/network-fallback-sys/class/net/wlan0/operstate"
printf '1\n' > "$TMPDIR/network-fallback-sys/class/net/wlan0/carrier"
SHELL_NETWORK_STATE=disconnected SHELL_NETWORK_LINKED=0 \
    SHELL_NETWORK_SYS_ROOT="$TMPDIR/network-fallback-sys" \
    network_env shell-network-listener status |
    jq -e '.ethernet.state == "connected" and .ethernet.connected == true and
           .ethernet.interface == "eno1" and .ethernet.ip == "198.51.100.5/24" and
           .wifi.available == true and .primary.kind == "ethernet"' >/dev/null

# iwd can be mid-restart when the listener first runs. The D-Bus call must be
# bounded so a hung daemon cannot block the only thread that emits state; the
# carrying wired link is still reported from sysfs.
cat > "$TMPDIR/network-bin/busctl-hang" <<'SH'
#!/bin/sh
exec sleep 600
SH
chmod +x "$TMPDIR/network-bin/busctl-hang"
SHELL_NETWORK_BUSCTL="$TMPDIR/network-bin/busctl-hang" \
    SHELL_NETWORK_SYS_ROOT="$TMPDIR/network-fallback-sys" \
    SHELL_NETWORK_TIMEOUT=1 \
    timeout 20 shell-network-listener status |
    jq -e '.ethernet.available == true and .ethernet.connected == true and
           .ethernet.interface == "eno1" and .primary.kind == "ethernet"' >/dev/null

# The network list carries each entry's position, so a row can select by index
# without interpolating an SSID into a shell command.
network_list=$(network_env shell-network-listener networks)
printf '%s\n' "$network_list" | jq -e '
    .scanning == false and (.networks | length) == 1 and
    .networks[0].index == 0 and .networks[0].ssid == "Home WiFi" and
    .networks[0].security == "psk" and .networks[0].signal == 50 and
    .networks[0].known == true and .networks[0].connected == true and
    (.top | length) == 1
' >/dev/null
: > "$TMPDIR/network-state/scanning"
network_env shell-network-listener networks | jq -e '.scanning == true' >/dev/null
rm -f "$TMPDIR/network-state/scanning"

# The watch helper does no list work while nothing is scanning, and emits the
# list once, with scanning cleared, for a scan that has finished.
test "$(network_env timeout 3 shell-network-listener watch 2>/dev/null | wc -l)" -eq 0
: > "$TMPDIR/network-state/scanning"
test "$(network_env timeout 3 shell-network-listener watch 2>/dev/null | wc -l)" -eq 1
rm -f "$TMPDIR/network-state/scanning"

# The full list is a Rofi menu; the chosen row comes back as an index, so the
# connect acts on the same numbered entry the inline rows use.
: > "$SHELL_NETWORK_LOG"
SHELL_NETWORK_PROMPT=0 network_env shell-network-listener menu
test "$(cat "$SHELL_NETWORK_LOG")" = 'station wlan0 disconnect'
: > "$SHELL_NETWORK_LOG"
SHELL_NETWORK_KNOWN=0 SHELL_NETWORK_LINKED=0 SHELL_NETWORK_STATE=disconnected \
    SHELL_NETWORK_PROMPT=0 SHELL_NETWORK_PASSPHRASE='correct horse' \
    network_env shell-network-listener menu
test "$(cat "$SHELL_NETWORK_LOG")" = '--passphrase=correct horse station wlan0 connect Home WiFi'

# Connecting to an unknown network prompts for a passphrase and hands it to
# the privileged iwctl call.
: > "$SHELL_NETWORK_LOG"
SHELL_NETWORK_KNOWN=0 SHELL_NETWORK_PASSPHRASE='correct horse' \
    network_env shell-network-listener connect 0
test "$(cat "$SHELL_NETWORK_LOG")" = '--passphrase=correct horse station wlan0 connect Home WiFi'
: > "$SHELL_NETWORK_LOG"
network_env shell-network-listener forget 0
test "$(cat "$SHELL_NETWORK_LOG")" = 'known-networks Home WiFi forget'
: > "$SHELL_NETWORK_LOG"
network_env shell-network-listener disconnect
test "$(cat "$SHELL_NETWORK_LOG")" = 'station wlan0 disconnect'

cat > "$TMPDIR/network-bin/date" <<'SH'
#!/bin/sh
set -eu
count=0
[ ! -f "$SHELL_NETWORK_DATE_COUNT" ] || read -r count < "$SHELL_NETWORK_DATE_COUNT"
count=$((count + 1))
printf '%s\n' "$count" > "$SHELL_NETWORK_DATE_COUNT"
# Each sample advances the clock by two seconds, so a rate is computable on
# any iteration after the byte counters change.
printf '%s\n' "$((100 + 2 * (count - 1)))"
SH
chmod +x "$TMPDIR/network-bin/date"
printf '1048576\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"
printf '524288\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
SHELL_NETWORK_BUSCTL="$TMPDIR/network-bin/busctl" \
    SHELL_NETWORK_IP="$TMPDIR/network-bin/ip" \
    SHELL_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
    SHELL_NETWORK_STATE_ROOT="$TMPDIR/network-state" \
    SHELL_NETWORK_DATE="$TMPDIR/network-bin/date" \
    SHELL_NETWORK_DATE_COUNT="$TMPDIR/network-date-count" \
    SHELL_NETWORK_INTERVAL=0.01 \
    shell-network-listener listen > "$TMPDIR/network-listener" &
network_pid=$!
wait_until has_lines "$TMPDIR/network-listener" 1
printf '3145728\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes"
printf '1572864\n' > "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes"
rate_seen() {
    jq -e 'select(.wifi.rx_bytes_per_second == 1048576 and .wifi.tx_bytes_per_second == 524288)' \
        "$TMPDIR/network-listener" >/dev/null 2>&1
}
wait_until rate_seen
kill "$network_pid" >/dev/null 2>&1 || true
wait "$network_pid" >/dev/null 2>&1 || true
mkdir -p "$TMPDIR/audio-bin"
cat > "$TMPDIR/audio-bin/wpctl" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    'set-mute @DEFAULT_AUDIO_SINK@ toggle' | 'set-mute @DEFAULT_AUDIO_SOURCE@ toggle' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+' | 'set-volume @DEFAULT_AUDIO_SINK@ 5%-' | 'set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+' | 'set-volume @DEFAULT_AUDIO_SOURCE@ 5%-' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%' | 'set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%' | 'set-default 43') printf '%s\n' "$*" >> "$SHELL_AUDIO_LOG" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/audio-bin/wpctl"
export SHELL_AUDIO_LOG="$TMPDIR/audio-actions"
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio toggle-sink
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio toggle-source
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio change-sink up
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio change-sink down
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio change-source up
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio change-source down
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio set-sink 55
SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio set-source 31.5
if SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio set-sink 101 >/dev/null 2>&1; then
    echo 'shell-audio accepted volume above its limit' >&2
    exit 1
fi
test "$(cat "$SHELL_AUDIO_LOG")" = 'set-mute @DEFAULT_AUDIO_SINK@ toggle
set-mute @DEFAULT_AUDIO_SOURCE@ toggle
set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
set-volume @DEFAULT_AUDIO_SINK@ 5%-
set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+
set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%
set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%'

SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio set-default 43
if SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio set-default invalid >/dev/null 2>&1; then
    echo 'shell-audio accepted a non-numeric PipeWire endpoint id' >&2
    exit 1
fi

# The OpenXLR monitor commands moved downstream with the audio popup
# extension. The helper must reject them rather than quietly succeeding.
for removed in monitor-status set-monitor set-default-output cycle-monitor; do
    if SHELL_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" shell-audio "$removed" >/dev/null 2>&1; then
        printf 'shell-audio accepted removed command: %s\n' "$removed" >&2
        exit 1
    fi
done

# The battery half reads sysfs and needs no daemon. The stub busctl is present
# but refuses every call, so the profile half must stay unavailable. The helper
# streams forever, so the first sample comes from a background process, as the
# hardware check reads its own.
mkdir -p "$TMPDIR/power-sys/class/power_supply/BAT0" "$TMPDIR/power-bin"
printf 'Battery\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/type"
printf 'Discharging\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/status"
printf '42\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/capacity"
printf '21000000\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/energy_now"
printf '50000000\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/energy_full"
printf '10000000\n' > "$TMPDIR/power-sys/class/power_supply/BAT0/power_now"
cat > "$TMPDIR/power-bin/busctl" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$TMPDIR/power-bin/busctl"

# Start the stream against a sysfs root and a busctl stub, keep its first
# sample, and stop it. A missing sysfs root is a machine with no battery.
capture_power() {
    : > "$3"
    SHELL_POWER_SYS_ROOT="$1" \
        SHELL_POWER_BUSCTL="$2" \
        SHELL_POWER_INTERVAL=10 \
        shell-power-status > "$3" 2>/dev/null &
    power_pid=$!
    wait_until has_lines "$3" 1
    kill "$power_pid" >/dev/null 2>&1 || true
    wait "$power_pid" >/dev/null 2>&1 || true
}

capture_power "$TMPDIR/power-sys" "$TMPDIR/power-bin/busctl" "$TMPDIR/power-battery"
sed -n '1p' "$TMPDIR/power-battery" |
    jq -e '
        .battery.present == true and .battery.percent == 42 and
        .battery.status == "discharging" and .battery.time_s == 7560 and
        .battery.warning == null and .battery.devices[0].name == "BAT0" and
        .profile.available == false
    ' >/dev/null

# A machine with no battery reports it as absent so the bar hides the cell.
capture_power "$TMPDIR/power-empty-sys" "$TMPDIR/power-bin/busctl" "$TMPDIR/power-none"
sed -n '1p' "$TMPDIR/power-none" |
    jq -e '.battery.present == false and .battery.percent == null' >/dev/null

# UPower refines the percent, time, and warning level when it answers, and the
# daemon supplies the active profile and its degraded flag.
cat > "$TMPDIR/power-bin/busctl" <<'SH'
#!/bin/sh
set -eu
case "$1 $2 $6" in
    '--system get-property ActiveProfile') printf 's "performance"\n' ;;
    '--system get-property PerformanceInhibited') printf 's ""\n' ;;
    '--system get-property PerformanceDegraded') printf 's "battery"\n' ;;
    '--system get-property Percentage') printf 'd 37.0\nt 5400\nt 0\nu 3\n' ;;
    '--system set-property '*) printf '%s\n' "$*" >> "$SHELL_POWER_LOG" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/power-bin/busctl"
capture_power "$TMPDIR/power-sys" "$TMPDIR/power-bin/busctl" "$TMPDIR/power-refined"
sed -n '1p' "$TMPDIR/power-refined" |
    jq -e '
        .battery.percent == 37 and .battery.time_s == 5400 and .battery.warning == 3 and
        .profile.available == true and .profile.active == "performance" and
        .profile.inhibited == false and .profile.degraded == true
    ' >/dev/null

# The set subcommand writes the daemon property through busctl and rejects a
# profile outside the three the bar offers.
export SHELL_POWER_LOG="$TMPDIR/power-calls"
: > "$SHELL_POWER_LOG"
SHELL_POWER_BUSCTL="$TMPDIR/power-bin/busctl" shell-power-status set power-saver
test "$(cat "$SHELL_POWER_LOG")" = '--system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s power-saver'
if SHELL_POWER_BUSCTL="$TMPDIR/power-bin/busctl" shell-power-status set turbo >/dev/null 2>&1; then
    echo 'shell-power-status accepted an unknown profile' >&2
    exit 1
fi

touch "$out"
