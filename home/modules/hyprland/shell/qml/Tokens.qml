pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    // The design tokens are generated from the Nix theme options.
    FileView {
        id: file
        path: Quickshell.env("SHELL_TOKENS")
        blockLoading: true
    }

    readonly property var data: JSON.parse(file.text())
    property string mode: data.defaultMode

    readonly property var c: data.colors[mode]
    readonly property string fontFamily: data.fonts.interface.family
    readonly property string monoFamily: data.fonts.monospace.family
    readonly property int fontSize: data.fonts.interface.size
    readonly property var radius: data.radius
    readonly property real cornerRoundingPower: data.cornerRoundingPower
    readonly property var spacing: data.spacing
    readonly property int borderWidth: data.borderWidth
    readonly property int barHeight: data.barHeight
    readonly property int barGap: data.barGap
    // A top-anchored panel measures from the bar's reserved area, which is the
    // bar height plus the gap, so this is the inset that leaves one small step
    // between the bar and the panel.
    readonly property int panelTopInset: Math.max(0, spacing.small - barGap)
    readonly property int popupPadding: data.popupPadding
    readonly property int fast: data.animation.fast
    readonly property int normal: data.animation.normal
    readonly property var popupWidth: data.popupWidth
    readonly property bool audioExtension: data.audioExtension === true
    readonly property bool powerProfiles: data.powerProfiles === true
    readonly property string username: data.username

    // The workspace markers sit one small step inside the bar's height.
    readonly property int workspaceCell: barHeight - spacing.small
    readonly property int slide: normal * 0.75
    readonly property var curve: [0.25, 0.8, 0.3, 1, 1, 1]
}
