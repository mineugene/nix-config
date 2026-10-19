import QtQuick

DesktopPopup {
    name: "hardware"

    function pct(v, digits) {
        return v === null || v === undefined || v < 0 ? " – " : v.toFixed(digits) + "%";
    }

    function num(v, digits, unit) {
        return v === null || v === undefined || v < -999 ? " – " : v.toFixed(digits) + unit;
    }

    function gib(v) {
        return v === null || v === undefined || v < 0 ? null : (v / 1024).toFixed(1);
    }

    function uptime(s) {
        if (s === null || s === undefined || s < 0)
            return " – ";
        if (s >= 86400)
            return Math.floor(s / 86400) + "d " + Math.floor((s % 86400) / 3600) + "h";
        if (s >= 3600)
            return Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m";
        return Math.floor(s / 60) + "m";
    }

    function load() {
        const values = [Hardware.cpu.load1, Hardware.cpu.load5, Hardware.cpu.load15];
        if (values.some(v => v === null || v === undefined || v < 0))
            return " – ";
        return values.map(v => v.toFixed(2)).join(" · ");
    }

    function frequency() {
        const current = Hardware.cpu.frequency_mhz;
        const peak = Hardware.cpu.frequency_max_mhz;
        if (current === null || current === undefined || current < 0)
            return " – ";
        let text = (current / 1000).toFixed(2) + " GHz";
        if (peak !== null && peak !== undefined && peak >= 0)
            text += " (▲ " + (peak / 1000).toFixed(2) + " GHz)";
        return text;
    }

    function memory() {
        const usage = Hardware.memory.usage;
        const used = Hardware.memory.used_gib;
        const total = Hardware.memory.total_gib;
        if (usage === null || usage === undefined || usage < 0)
            return " – ";
        let text = usage.toFixed(0) + "%";
        if (used !== null && used !== undefined && used >= 0 && total !== null && total !== undefined && total >= 0)
            text += " (" + used.toFixed(1) + " / " + total.toFixed(1) + " GiB)";
        return text;
    }

    function storage(device) {
        return device.percent + "% (" + device.used + " / " + device.size + ")";
    }

    function swap() {
        const usage = Hardware.memory.swap_usage;
        const used = Hardware.memory.swap_used_gib;
        const total = Hardware.memory.swap_total_gib;
        if (total === null || total === undefined || total <= 0)
            return " – ";
        let text = usage.toFixed(0) + "%";
        if (used !== null && used !== undefined && used >= 0)
            text += " (" + used.toFixed(1) + " / " + total.toFixed(1) + " GiB)";
        return text;
    }

    PopupTitle {
        text: "Hardware"
    }

    PopupSection {
        title: "CPU"
        PopupDetail {
            name: "Utilization"
            value: pct(Hardware.cpu.usage, 0)
        }
        PopupDetail {
            name: "Frequency"
            value: frequency()
        }
        PopupDetail {
            name: "Load (1 / 5 / 15 min)"
            value: load()
        }
        PopupDetail {
            name: "Power"
            value: num(Hardware.cpu.power_w, 1, " W")
        }
        PopupDetail {
            name: "Temperature"
            value: num(Hardware.cpu.temp_c, 1, " °C")
        }
    }

    PopupSection {
        title: "GPU"
        visible: Hardware.gpuPresent
        PopupDetail {
            name: "Utilization"
            value: pct(Hardware.gpu.usage, 0)
        }
        PopupDetail {
            name: "VRAM"
            readonly property var used: gib(Hardware.gpu.vram_used_mib)
            readonly property var total: gib(Hardware.gpu.vram_total_mib)
            value: used === null || total === null ? " – " : used + " / " + total + " GiB"
        }
        PopupDetail {
            name: "Power"
            value: num(Hardware.gpu.power_w, 1, " W")
        }
        PopupDetail {
            name: "Temperature"
            value: num(Hardware.gpu.temp_c, 1, " °C")
        }
    }

    PopupSection {
        title: "Memory"
        PopupDetail {
            name: "Utilization"
            value: memory()
        }
        PopupDetail {
            name: "Available"
            value: num(Hardware.memory.available_gib, 1, " GiB")
        }
        PopupDetail {
            name: "Cache"
            value: num(Hardware.memory.cache_gib, 1, " GiB")
        }
        PopupDetail {
            name: "Swap"
            value: swap()
        }
    }

    PopupSection {
        title: "Storage"
        Repeater {
            model: Hardware.storage.devices ?? []
            delegate: PopupDetail {
                required property var modelData
                name: modelData.mount
                value: storage(modelData)
            }
        }
        PopupDetail {
            name: "Temperature"
            value: num(Hardware.storage.temp_c, 0, " °C")
        }
    }

    PopupSection {
        title: "Cooling"
        visible: Hardware.coolingAvailable
        PopupDetail {
            name: "CPU fan"
            value: num(Hardware.cooling.cpu_fan_rpm, 0, " RPM")
        }
        PopupDetail {
            name: "AIO pump"
            visible: Hardware.cooling.aio_pump_rpm !== null && Hardware.cooling.aio_pump_rpm !== undefined
            value: num(Hardware.cooling.aio_pump_rpm, 0, " RPM")
        }
    }

    PopupSection {
        title: "Uptime"
        PopupDetail {
            name: "Running"
            value: uptime(Hardware.uptime)
        }
    }
}