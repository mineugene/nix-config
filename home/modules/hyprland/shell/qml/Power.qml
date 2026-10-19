pragma Singleton

import QtQuick
import Quickshell

// Battery charge and the power-profiles-daemon profile, streamed by
// shell-power-status. Every field has a hidden-state default so the bar never
// claims a battery or a daemon it has not heard from.
Singleton {
    id: root

    readonly property var emptyBattery: ({
            present: false,
            percent: null,
            status: "unknown",
            time_s: null,
            warning: null,
            devices: []
        })
    readonly property var emptyProfile: ({
            available: false,
            active: "",
            inhibited: false,
            degraded: false
        })

    JsonStream {
        id: stream
        command: ["shell-power-status"]
    }

    readonly property var battery: stream.value?.battery ?? emptyBattery
    readonly property var profile: stream.value?.profile ?? emptyProfile
    readonly property bool profileAvailable: profile.available === true

    readonly property string batteryCharging: "\u{F0084}"
    readonly property string batteryFull: "\u{F0079}"
    readonly property string batteryOutline: "\u{F008E}"
    readonly property string batteryUnknown: "\u{F125D}"
    readonly property var batteryLevels: [
        "\u{F007A}",
        "\u{F007B}",
        "\u{F007C}",
        "\u{F007D}",
        "\u{F007E}",
        "\u{F007F}",
        "\u{F0080}",
        "\u{F0081}",
        "\u{F0082}"
    ]

    readonly property string profilePowerSaver: "\u{F06C}"
    readonly property string profileBalanced: "\u{F24E}"
    readonly property string profilePerformance: "\u{F140B}"
    readonly property string profileOther: "\u{F15C1}"
    readonly property string profileInhibited: "\u{F057}"
    readonly property string profileDegraded: "\u{F06A}"
    readonly property string profileSwitching: "\u{F10C}"

    readonly property var profileNames: [
        "power-saver",
        "balanced",
        "performance"
    ]

    property string pendingProfile: ""
    property bool switching: false

    // The icon steps in ten-percent buckets; the exact percent lives on the
    // ring and in the tooltip.
    function batteryIcon() {
        if (battery.present !== true)
            return "";
        if (battery.status === "charging")
            return batteryCharging;
        if (battery.status === "unknown")
            return batteryUnknown;
        const percent = battery.percent;
        if (battery.status === "full" || (percent !== null && percent >= 95))
            return batteryFull;
        if (percent === null || percent <= 4)
            return batteryOutline;
        const index = Math.min(8, Math.max(0, Math.floor((percent - 5) / 10)));
        return batteryLevels[index];
    }

    function batteryRingValue() {
        return battery.present === true && battery.percent !== null ? battery.percent : 0;
    }

    // Severity is a discharge concern: charging and full keep the normal tint.
    // UPower's warning level wins when the daemon supplies it.
    function batterySeverity() {
        if (battery.present !== true || battery.status !== "discharging")
            return "normal";
        const percent = battery.percent ?? 100;
        const warning = battery.warning;
        if ((warning !== null && warning >= 4) || percent <= 10)
            return "critical";
        if ((warning !== null && warning >= 3) || percent <= 20)
            return "warning";
        return "normal";
    }

    function timeText(seconds) {
        if (seconds === null || seconds === undefined || seconds <= 0)
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    function batteryStateText() {
        switch (battery.status) {
        case "charging":
            return "Charging";
        case "discharging":
            return "Discharging";
        case "full":
            return "Full";
        case "not-charging":
            return "Not charging";
        default:
            return "Unknown";
        }
    }

    function batteryTooltip() {
        if (battery.present !== true)
            return "";
        let text = "Battery " + (battery.percent ?? "?") + "% · " + batteryStateText().toLowerCase();
        const time = timeText(battery.time_s);
        if (time !== "")
            text += " · " + time + (battery.status === "charging" ? " to full" : " left");
        return text;
    }

    function profileIcon() {
        if (!profileAvailable)
            return "";
        if (profile.inhibited === true)
            return profileInhibited;
        if (profile.degraded === true)
            return profileDegraded;
        if (switching)
            return profileSwitching;
        switch (profile.active) {
        case "power-saver":
            return profilePowerSaver;
        case "balanced":
            return profileBalanced;
        case "performance":
            return profilePerformance;
        default:
            return profileOther;
        }
    }

    function profileLabel(name) {
        switch (name) {
        case "power-saver":
            return "Power saver";
        case "balanced":
            return "Balanced";
        case "performance":
            return "Performance";
        default:
            return name;
        }
    }

    function profileTooltip() {
        if (!profileAvailable)
            return "";
        if (profile.inhibited === true)
            return profileLabel(profile.active) + " · inhibited";
        if (profile.degraded === true)
            return profileLabel(profile.active) + " · degraded";
        return profileLabel(profile.active || "unknown");
    }

    function setProfile(name) {
        if (!profileAvailable || profile.active === name)
            return;
        pendingProfile = name;
        switching = true;
        switchGuard.restart();
        Quickshell.execDetached(["shell-power-status", "set", name]);
    }

    function cycle() {
        if (!profileAvailable)
            return;
        const index = profileNames.indexOf(profile.active);
        setProfile(profileNames[(index + 1) % profileNames.length]);
    }

    onProfileChanged: {
        if (pendingProfile !== "" && profile.active === pendingProfile) {
            switching = false;
            pendingProfile = "";
            switchGuard.stop();
        }
    }

    Timer {
        id: switchGuard
        interval: 8000
        onTriggered: {
            root.switching = false;
            root.pendingProfile = "";
        }
    }
}