#!/bin/sh
set -eu
: "${hardwareStatusCommand:?}" "${hyprlandListenerSource:?}" "${audioSource:?}" "${out:?}"
: "${waitHelpers:?}" "${audioListenerTest:?}"
# shellcheck source=/dev/null
. "$waitHelpers"

mkdir -p "$TMPDIR/bluetooth-bin"
cat > "$TMPDIR/bluetooth-bin/bluetoothctl" <<'SH'
#!/bin/sh
exec sleep 600
SH
chmod +x "$TMPDIR/bluetooth-bin/bluetoothctl"
EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl" \
    timeout 30 eww-bluetooth status |
    jq -e '.available == false and .powered == false' >/dev/null

# A powered adapter with a headset attached: connected and audio are
# separate states because they are drawn with separate glyphs.
mkdir -p "$TMPDIR/bluetooth-sys/class/bluetooth/hci0"
cat > "$TMPDIR/bluetooth-bin/bluetoothctl-powered" <<'SH'
#!/bin/sh
set -eu
case "$*" in
    show) printf 'Powered: yes\n' ;;
    'devices Connected') printf '%s' "${EWW_BLUETOOTH_DEVICES-Device AA:BB:CC:DD:EE:FF Headset}" ;;
    'info AA:BB:CC:DD:EE:FF') printf 'Icon: %s\n' "${EWW_BLUETOOTH_ICON:-audio-headset}" ;;
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
EWW_BLUETOOTH_DEVICES='' \
    EWW_BLUETOOTHCTL="$TMPDIR/bluetooth-bin/bluetoothctl-powered" \
    EWW_BLUETOOTH_SYS_ROOT="$TMPDIR/bluetooth-sys" \
    eww-bluetooth status |
    jq -e '.powered == true and .connected == false and .audio == false' >/dev/null

# The frame is a clock read, so a fixed clock pins a known frame and
# the sequence must wrap rather than grow.
mkdir -p "$TMPDIR/animation-bin"
cat > "$TMPDIR/animation-bin/date" <<'SH'
#!/bin/sh
printf '%s\n' "${EWW_ANIMATION_NOW:-1000}"
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
has_lines() {
    [ "$(wc -l < "$1")" -ge "$2" ]
}
# Each FIFO write waits for evidence that the previous read closed it;
# otherwise two samples can share one open and the second is dropped.
{
    printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
    wait_until test -s "$EWW_HYPRCTL_LOG"
    printf 'cpu  150 0 150 900 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
    wait_until has_lines "$TMPDIR/hardware-status" 1
    printf 'cpu  200 0 200 1000 0 0 0 0 0 0\n' > "$TMPDIR/hardware-proc/stat"
} &
stat_writer=$!
PATH="$TMPDIR/hardware-bin:$PATH" \
    EWW_HARDWARE_HYPRCTL="$TMPDIR/hardware-bin/hyprctl" \
    EWW_HARDWARE_INTERVAL=1 \
    EWW_HARDWARE_PROC_ROOT="$TMPDIR/hardware-proc" \
    EWW_HARDWARE_SYS_ROOT="$TMPDIR/hardware-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/hardware-status" &
hardware_pid=$!
wait_until has_lines "$TMPDIR/hardware-status" 2
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
printf 'cpu  100 0 100 800 0 0 0 0 0 0\n' > "$TMPDIR/missing-proc/stat"
PATH="$TMPDIR/missing-bin" \
    EWW_HARDWARE_INTERVAL=1 \
    EWW_HARDWARE_PROC_ROOT="$TMPDIR/missing-proc" \
    EWW_HARDWARE_SYS_ROOT="$TMPDIR/missing-sys" \
    "$hardwareStatusCommand" > "$TMPDIR/missing-status" &
missing_hardware_pid=$!
wait_until test -s "$TMPDIR/missing-status"
kill "$missing_hardware_pid" >/dev/null 2>&1 || true
wait "$missing_hardware_pid" >/dev/null 2>&1 || true
missing_line=$(head -n 1 "$TMPDIR/missing-status")
printf '%s\n' "$missing_line" | jq -e '
    .cpu.temp_c == null and
    .cpu.frequency_mhz == null and
    .gpu.usage == null and
    .display.name == null and
    .display.automatic_hdr == null
' >/dev/null

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
listener_runtime="$TMPDIR/listener-runtime"
mkdir "$listener_runtime"
hypr_path="$TMPDIR/hypr-bin:$PATH"
TMPDIR="$listener_runtime" PATH="$hypr_path" dash "$hyprlandListenerSource" \
    > "$TMPDIR/listener-out" 2> "$TMPDIR/listener-err" &
listener_pid=$!
wait_until test -s "$TMPDIR/listener-out"
kill "$listener_pid"
wait "$listener_pid" || true
test -z "$(find "$listener_runtime" -mindepth 1 -print -quit)" || {
    echo 'hyprland listener left temporary files' >&2
    exit 1
}
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
    '--terse --escape no --fields DEVICE,TYPE,STATE,CONNECTION device status') printf '%s\n' "${EWW_NETWORK_DEVICES:-wlan0:wifi:connected:Home WiFi}" ;;
    '--terse --escape no --fields IN-USE,SIGNAL,SSID device wifi list ifname wlan0') printf '%s\n' '*:78:Home WiFi' ;;
    '--get-values IP4.ADDRESS device show wlan0') printf '%s\n' '192.0.2.10/24' ;;
    'networking connectivity') printf '%s\n' "${EWW_NETWORK_CONNECTIVITY:-full}" ;;
    'radio wifi') printf '%s\n' "${EWW_NETWORK_WIFI_RADIO:-enabled}" ;;
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
write_network_counter() (
    fifo=$1
    printf '%s\n' "$2" > "$fifo"
    # The first sample proves both temporary reader descriptors have closed.
    wait_until test -s "$TMPDIR/network-listener"
    printf '%s\n' "$3" > "$fifo"
)
write_network_counter "$TMPDIR/network-sys/class/net/wlan0/statistics/rx_bytes" 1048576 3145728 &
network_rx_writer=$!
write_network_counter "$TMPDIR/network-sys/class/net/wlan0/statistics/tx_bytes" 524288 1572864 &
network_tx_writer=$!
EWW_NETWORK_DATE="$TMPDIR/network-bin/date" \
    EWW_NETWORK_DATE_COUNT="$TMPDIR/network-date-count" \
    EWW_NETWORK_INTERVAL=0.01 \
    EWW_NETWORK_NMCLI="$TMPDIR/network-bin/nmcli" \
    EWW_NETWORK_SYS_ROOT="$TMPDIR/network-sys" \
    eww-network-listener listen > "$TMPDIR/network-listener" &
network_pid=$!
wait_until has_lines "$TMPDIR/network-listener" 2
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
    'inspect @DEFAULT_AUDIO_SINK@') [ "${EWW_AUDIO_INSPECT_FAIL:-0}" -eq 0 ] || exit 1; printf '%s\n' 'node.description = "Speakers"' ;;
    'inspect @DEFAULT_AUDIO_SOURCE@') [ "${EWW_AUDIO_INSPECT_FAIL:-0}" -eq 0 ] || exit 1; printf '%s\n' 'node.description = "Microphone"' ;;
    'status') printf '%s\n' ' ├─ Sinks:' ' │  *   42. Speakers [vol: 0.42 MUTED]' ' │      43. OpenXLR Chat [vol: 1.00]' ' ├─ Sources:' ' │      73. Microphone [vol: 0.73]' ' ├─ Filters:' ' │     99. Internal filter [Audio/Sink]' ;;
    'set-mute @DEFAULT_AUDIO_SINK@ toggle' | 'set-mute @DEFAULT_AUDIO_SOURCE@ toggle' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+' | 'set-volume @DEFAULT_AUDIO_SINK@ 5%-' | 'set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+' | 'set-volume @DEFAULT_AUDIO_SOURCE@ 5%-' | 'set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%' | 'set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%' | 'set-default 43') printf '%s\n' "$*" >> "$EWW_AUDIO_LOG" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/audio-bin/wpctl"
export EWW_AUDIO_LOG="$TMPDIR/audio-actions"
audio_status=$(EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status)
printf '%s\n' "$audio_status" | jq -e '
    .available == true and
    .sink.muted == true and .sink.volume == 42 and .sink.description == "Speakers" and
    .source.muted == false and .source.volume == 73 and .source.description == "Microphone" and
    .outputs == [{kind: "outputs", id: 42, label: "Speakers", active: true}, {kind: "outputs", id: 43, label: "OpenXLR Chat", active: false}] and
    .inputs == [{kind: "inputs", id: 73, label: "Microphone", active: false}]
' >/dev/null
EWW_AUDIO_INSPECT_FAIL=1 EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio status |
    jq -e '.sink.description == "Default audio device" and .source.description == "Default audio device"' >/dev/null

# Capture detection: a running input stream means an application holds
# the microphone open. An idle stream does not, and neither does a
# graph that cannot be read.
cat > "$TMPDIR/audio-bin/pw-dump" <<'SH'
#!/bin/sh
set -eu
if [ -n "${EWW_AUDIO_PWDUMP_LOG:-}" ]; then
    printf 'called\n' >> "$EWW_AUDIO_PWDUMP_LOG"
fi
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

python3 "$audioListenerTest"
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio toggle-sink
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio toggle-source
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-sink up
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-sink down
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-source up
EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio change-source down
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
set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+
set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
set-volume -l 1 @DEFAULT_AUDIO_SINK@ 55%
set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 31.5%'

EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio set-default 43
if EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl" eww-audio set-default invalid >/dev/null 2>&1; then
    echo 'eww-audio accepted a non-numeric PipeWire endpoint id' >&2
    exit 1
fi

# Monitor-output commands: OpenXLR stays the authority, the helper
# only reads and commands its HTTP API. The wrapper carries the two
# dummy entries configured for this check, which doubles as the
# evaluation test that the option reaches the built helper.
mkdir -p "$TMPDIR/audio-xdg/openxlr" "$TMPDIR/audio-xdg-empty"
printf '%s' '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    > "$TMPDIR/audio-xdg/openxlr/token"
export EWW_AUDIO_OPENXLR_LOG="$TMPDIR/audio-openxlr-actions"
cat > "$TMPDIR/audio-bin/curl" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$EWW_AUDIO_OPENXLR_LOG"
case "$*" in
    *'api/v1/state'*)
        [ "${EWW_AUDIO_STATE_FAIL:-0}" -eq 0 ] || exit 1
        cat "$EWW_AUDIO_STATE"
        ;;
    *'api/v1/commands'*)
        printf '{"apiVersion":"1","ok":true,"messages":[]}'
        ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TMPDIR/audio-bin/curl"
cat > "$TMPDIR/audio-state-both" <<'JSON'
{"type":"state","mixer":{"monitorOutput":"alsa_output.usb-Check_Headphones-00.analog-stereo","monitorOutputs":["alsa_output.usb-Check_Headphones-00.analog-stereo"],"enforcedDefaultSink":"alsa_output.usb-Check_Headphones-00.analog-stereo"},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Speakers-00.analog-stereo","kind":0},{"name":"alsa_input.usb-Check_Mic-00.mono-fallback","kind":1}]}
JSON
cat > "$TMPDIR/audio-state-speakers-missing" <<'JSON'
{"type":"state","mixer":{"monitorOutput":"alsa_output.usb-Check_Headphones-00.analog-stereo","monitorOutputs":["alsa_output.usb-Check_Headphones-00.analog-stereo"]},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0}]}
JSON
cat > "$TMPDIR/audio-state-active-speakers" <<'JSON'
{"type":"state","mixer":{"monitorOutput":"alsa_output.usb-Check_Speakers-00.analog-stereo","monitorOutputs":["alsa_output.usb-Check_Speakers-00.analog-stereo"],"enforcedDefaultSink":"alsa_output.usb-Check_Speakers-00.analog-stereo"},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Speakers-00.analog-stereo","kind":0}]}
JSON
cat > "$TMPDIR/audio-state-none" <<'JSON'
{"type":"state","mixer":{"monitorOutput":null,"monitorOutputs":[]},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Speakers-00.analog-stereo","kind":0}]}
JSON
cat > "$TMPDIR/audio-state-malformed" <<'JSON'
{"type":"error"}
JSON
# The enforced default is unset, and one outside the allowlist: the
# submenu then lights no row, and the foreign sink is still reported
# verbatim so the popup can tell "not enforced" from "elsewhere".
cat > "$TMPDIR/audio-state-default-none" <<'JSON'
{"type":"state","mixer":{"monitorOutput":"alsa_output.usb-Check_Headphones-00.analog-stereo","monitorOutputs":["alsa_output.usb-Check_Headphones-00.analog-stereo"],"enforcedDefaultSink":null},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Speakers-00.analog-stereo","kind":0}]}
JSON
cat > "$TMPDIR/audio-state-default-foreign" <<'JSON'
{"type":"state","mixer":{"monitorOutput":"alsa_output.usb-Check_Headphones-00.analog-stereo","monitorOutputs":["alsa_output.usb-Check_Headphones-00.analog-stereo"],"enforcedDefaultSink":"alsa_output.usb-Check_Hdmi-00"},"devices":[{"name":"alsa_output.usb-Check_Headphones-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Speakers-00.analog-stereo","kind":0},{"name":"alsa_output.usb-Check_Hdmi-00","kind":0}]}
JSON

XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-both" \
    eww-audio monitor-status | jq -e '
        .available == true and
        .active == "alsa_output.usb-Check_Headphones-00.analog-stereo" and
        .default == "alsa_output.usb-Check_Headphones-00.analog-stereo" and
        (.outputs | length) == 2 and
        .outputs[0].label == "Headphones" and
        .outputs[0].available == true and .outputs[0].active == true and
        .outputs[1].label == "Speakers" and
        .outputs[1].available == true and .outputs[1].active == false
    ' >/dev/null
# A configured sink missing from the daemon's devices stays listed
# but unavailable.
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-speakers-missing" \
    eww-audio monitor-status |
    jq -e '.outputs[1].available == false and .outputs[1].active == false' >/dev/null
# The enforced default reads back from the same state: unset reports
# null, and a sink outside the allowlist is reported verbatim.
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-default-none" \
    eww-audio monitor-status |
    jq -e '.default == null' >/dev/null
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-default-foreign" \
    eww-audio monitor-status |
    jq -e '.default == "alsa_output.usb-Check_Hdmi-00" and .active == "alsa_output.usb-Check_Headphones-00.analog-stereo"' >/dev/null
# Daemon unreachable, unreadable token, and a malformed reply all
# degrade without hiding the configured outputs.
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-both" \
    EWW_AUDIO_STATE_FAIL=1 \
    eww-audio monitor-status |
    jq -e '.available == false and .active == null and .default == null and .outputs[0].available == false and (.outputs | length) == 2' >/dev/null
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg-empty" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-both" \
    eww-audio monitor-status |
    jq -e '.available == false and .active == null' >/dev/null
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-malformed" \
    eww-audio monitor-status |
    jq -e '.available == false and .active == null' >/dev/null

: > "$EWW_AUDIO_OPENXLR_LOG"
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    eww-audio set-monitor alsa_output.usb-Check_Speakers-00.analog-stereo
grep -Fq 'Authorization: Bearer 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' "$EWW_AUDIO_OPENXLR_LOG"
grep -Fq -- '-d {"cmd":"setMonitorOutput","device":"alsa_output.usb-Check_Speakers-00.analog-stereo"}' "$EWW_AUDIO_OPENXLR_LOG"
grep -Fq 'http://127.0.0.1:37890/api/v1/commands' "$EWW_AUDIO_OPENXLR_LOG"

# The default-output submenu switches the enforced default through the
# same gate: allowlist first, then setMainOutput.
: > "$EWW_AUDIO_OPENXLR_LOG"
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    eww-audio set-default-output alsa_output.usb-Check_Headphones-00.analog-stereo
grep -Fq -- '-d {"cmd":"setMainOutput","device":"alsa_output.usb-Check_Headphones-00.analog-stereo"}' "$EWW_AUDIO_OPENXLR_LOG"

# A node outside the configured outputs is refused before any request,
# whichever selector asks.
: > "$EWW_AUDIO_OPENXLR_LOG"
if XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    eww-audio set-monitor alsa_output.usb-Foreign-00.analog-stereo >/dev/null 2>&1; then
    echo 'eww-audio set a monitor output outside the allowlist' >&2
    exit 1
fi
if XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    eww-audio set-default-output alsa_output.usb-Foreign-00.analog-stereo >/dev/null 2>&1; then
    echo 'eww-audio set a default output outside the allowlist' >&2
    exit 1
fi
[ ! -s "$EWW_AUDIO_OPENXLR_LOG" ] || {
    echo 'an output command reached the daemon despite rejection' >&2
    exit 1
}

# Cycling picks the other available output, wrapping and starting
# from the first when nothing is selected.
: > "$EWW_AUDIO_OPENXLR_LOG"
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-both" \
    eww-audio cycle-monitor
grep -Fq -- '-d {"cmd":"setMonitorOutput","device":"alsa_output.usb-Check_Speakers-00.analog-stereo"}' "$EWW_AUDIO_OPENXLR_LOG"
: > "$EWW_AUDIO_OPENXLR_LOG"
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-active-speakers" \
    eww-audio cycle-monitor
grep -Fq -- '-d {"cmd":"setMonitorOutput","device":"alsa_output.usb-Check_Headphones-00.analog-stereo"}' "$EWW_AUDIO_OPENXLR_LOG"
: > "$EWW_AUDIO_OPENXLR_LOG"
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-none" \
    eww-audio cycle-monitor
grep -Fq -- '-d {"cmd":"setMonitorOutput","device":"alsa_output.usb-Check_Headphones-00.analog-stereo"}' "$EWW_AUDIO_OPENXLR_LOG"

# An empty allowlist degrades the monitor commands; the raw source is
# used because the wrapper always wires the configured entries.
XDG_RUNTIME_DIR="$TMPDIR/audio-xdg" \
    EWW_AUDIO_CURL="$TMPDIR/audio-bin/curl" \
    EWW_AUDIO_STATE="$TMPDIR/audio-state-both" \
    EWW_AUDIO_MONITOR_OUTPUTS='[]' \
    sh "$audioSource" monitor-status |
    jq -e '.available == false and .active == null and (.outputs | length) == 0' >/dev/null
if EWW_AUDIO_MONITOR_OUTPUTS='[]' \
    sh "$audioSource" set-monitor alsa_output.usb-Check_Speakers-00.analog-stereo >/dev/null 2>&1; then
    echo 'set-monitor accepted a node with no configured outputs' >&2
    exit 1
fi

if [ "${EWW_RUNTIME_ONLY:-0}" = 1 ]; then
    touch "$out"
    exit 0
fi

: "${ewwCommand:?}" "${popupToggle:?}" "${yuck:?}" "${scss:?}" "${theme:?}" "${bar:?}"
: "${commonPopups:?}" "${audioPopup:?}" "${calendar:?}" "${hardwarePopup:?}" "${menuPopup:?}"
: "${profilePopup:?}" "${networkPopup:?}" "${audio:?}" "${bluetooth:?}" "${clock:?}" "${hardware:?}"
: "${menu:?}" "${network:?}" "${notifications:?}" "${profile:?}" "${themeWidget:?}" "${tray:?}"
: "${window:?}" "${workspaces:?}" "${smokeScript:?}" "${dbusConfig:?}"

popup_toggle="$TMPDIR/popup-toggle"
mkdir -p "$TMPDIR/bin"
sed \
    -e "s|$ewwCommand|$TMPDIR/bin/eww|g" \
    "$popupToggle" > "$popup_toggle"
# The detached re-exec of the script needs the file to be runnable.
chmod +x "$popup_toggle"
cat > "$TMPDIR/bin/eww" <<'SH'
#!/bin/sh
set -eu

printf '%s\n' "$*" >> "$EWW_LOG"
case "$1" in
    active-windows)
        cat "$EWW_ACTIVE"
        ;;
    # The stub maintains the window list, so a run observes what
    # earlier runs actually opened: that is what makes the
    # serialisation test below meaningful.
    open)
        printf '%s\n' "$2: $2" >> "$EWW_ACTIVE"
        ;;
    close)
        grep -Fv -- "$2: $2" "$EWW_ACTIVE" > "$EWW_ACTIVE.tmp" || true
        mv "$EWW_ACTIVE.tmp" "$EWW_ACTIVE"
        ;;
    update)
        ;;
    *)
        exit 1
        ;;
esac
SH
chmod +x "$TMPDIR/bin/eww"
export EWW_LOG="$TMPDIR/eww-actions"
export EWW_ACTIVE="$TMPDIR/eww-active-windows"
export EWW_POPUP_STATE_ROOT="$TMPDIR/popup-state"
: > "$EWW_LOG"
printf 'bar: bar\n' > "$EWW_ACTIVE"

if sh "$popup_toggle" >/dev/null 2>&1; then
    echo 'popup-toggle accepted a missing popup name' >&2
    exit 1
fi
if sh "$popup_toggle" unknown >/dev/null 2>&1; then
    echo 'popup-toggle accepted an unknown popup name' >&2
    exit 1
fi
test ! -s "$EWW_LOG"

# Nothing but the bars is open, so a fresh open sweeps nothing closed.
# The busy flag brackets the run: set after the lock, cleared by the
# exit trap, so the bar cannot stay dimmed on any observable exit.
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" calendar
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
open popup-backdrop
open popup-backdrop-secondary
open calendar
update open_popup=calendar
update popup_busy=false'

# Selecting another control replaces the open popup, and backdrops
# that are already mapped are neither closed nor opened again.
printf 'bar: bar\nhardware: hardware\npopup-backdrop: popup-backdrop\npopup-backdrop-secondary: popup-backdrop-secondary\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" calendar
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
close hardware
open calendar
update open_popup=calendar
update popup_busy=false'

# Toggling the open popup off dismisses it with its backdrop.
printf 'bar: bar\nhardware: hardware\npopup-backdrop: popup-backdrop\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" hardware
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
close hardware
close popup-backdrop
update open_popup=
update popup_busy=false'

# close-all dismisses everything that is open and nothing else.
printf 'bar: bar\ncalendar: calendar\npopup-backdrop: popup-backdrop\npopup-backdrop-secondary: popup-backdrop-secondary\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" close-all
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
close calendar
close popup-backdrop
close popup-backdrop-secondary
update open_popup=
update popup_busy=false'

# close-all with nothing open still clears the published name.
printf 'bar: bar\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" close-all
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
update open_popup=
update popup_busy=false'

for popup in audio audio-output audio-input menu; do
    POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" "$popup"
    grep -Fxq "$popup: $popup" "$EWW_ACTIVE"
    test "$(wc -l < "$EWW_ACTIVE")" -eq 4 || {
        echo 'Audio pickers must replace peer popups and retain both backdrops' >&2
        exit 1
    }
done
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" close-all
test "$(cat "$EWW_ACTIVE")" = 'bar: bar'

# Rapid clicks serialise on the lock: the queued run must observe the
# windows its predecessor opened, close them, and leave exactly one
# popup open. Without the lock both runs snapshot nothing and both
# popups stay open.
printf 'bar: bar\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" hardware &
first_toggle=$!
POPUP_TOGGLE_FOREGROUND=1 sh "$popup_toggle" network &
second_toggle=$!
wait "$first_toggle"
wait "$second_toggle"
if grep -Fxq 'hardware: hardware' "$EWW_ACTIVE"; then
    grep -Fxq 'network: network' "$EWW_ACTIVE" && {
        echo 'serialised toggles stacked both popups' >&2
        exit 1
    }
    winner=hardware
    loser=network
elif grep -Fxq 'network: network' "$EWW_ACTIVE"; then
    winner=network
    loser=hardware
else
    echo 'serialised toggles left no popup open' >&2
    exit 1
fi
grep -Fq "close $loser" "$EWW_LOG" || {
    echo 'queued toggle never closed its predecessor' >&2
    exit 1
}
grep -Fq "update open_popup=$winner" "$EWW_LOG" || {
    echo 'serialised toggles never published the final state' >&2
    exit 1
}
test "$(grep -c 'update popup_busy=true' "$EWW_LOG")" = 2
test "$(grep -c 'update popup_busy=false' "$EWW_LOG")" = 2

# The click detaches itself so eww cannot kill it on its 200ms widget
# command timeout; the detached copy must still finish the sequence.
printf 'bar: bar\n' > "$EWW_ACTIVE"
: > "$EWW_LOG"
sh "$popup_toggle" calendar
wait_until grep -Fq 'update popup_busy=false' "$EWW_LOG" || {
    echo 'detached popup-toggle never completed its run' >&2
    exit 1
}
test "$(cat "$EWW_LOG")" = 'update popup_busy=true
active-windows
open popup-backdrop
open popup-backdrop-secondary
open calendar
update open_popup=calendar
update popup_busy=false'

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
: > "$TMPDIR/menu-bin/btm"
chmod +x "$TMPDIR/menu-bin"/*
export EWW_MENU_BTM="$TMPDIR/menu-bin/btm"
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
hyprctl:dispatch hl.dsp.exec_cmd('[float; center; size 1100 720] $EWW_MENU_TERMINAL -e $EWW_MENU_BTM')"
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
export EWW_AUDIO_WPCTL="$TMPDIR/audio-bin/wpctl"
# shellcheck disable=SC2174
mkdir -m 700 -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

cp "$smokeScript" "$TMPDIR/eww-smoke"
chmod +x "$TMPDIR/eww-smoke"

if ! dbus-run-session --config-file="$dbusConfig" -- \
    xvfb-run -a "$TMPDIR/eww-smoke" "$config_dir" "$TMPDIR/eww.log"; then
    if [ -f "$TMPDIR/eww.log" ]; then
        cat "$TMPDIR/eww.log" >&2
    fi
    exit 1
fi

touch "$out"
