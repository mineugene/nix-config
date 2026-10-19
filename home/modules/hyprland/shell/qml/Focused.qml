pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The focused window, as the bar and the menu name it.
Singleton {
    // Hyprland.activeToplevel keeps the last window when focus moves to an
    // empty workspace. Wayland clears its active handle on deactivation, so it
    // gates the stale Hyprland object.
    readonly property var window: ToplevelManager.activeToplevel ? Hyprland.activeToplevel : null
    readonly property var ipc: window?.lastIpcObject ?? ({})
    // Hyprland reports a window's object only in its openwindow event, and only
    // the title survives that event, so a window opened after the shell starts
    // has no class until its toplevel is fetched again.
    readonly property string app: ipc.initialTitle || ipc.class || ""

    readonly property string address: ipc.address ?? (window?.address ? "0x" + window.address.replace(/^0x/, "") : "")

    onWindowChanged: if (window && app === "")
        Hyprland.refreshToplevels()

    // The app name is shown apart from the window title, so a title that
    // repeats it must drop its copy or the bar reads it twice. The name is
    // matched literally and case-insensitively.
    function clean(name, text) {
        if (name === "")
            return text;
        const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return text.replace(new RegExp(escaped, "gi"), "").replace(/\s+/g, " ").replace(/^[\s—–\-|·:]+/, "").replace(/[\s—–\-|·:]+$/, "");
    }

    readonly property string title: clean(app, window?.title ?? "")
}
