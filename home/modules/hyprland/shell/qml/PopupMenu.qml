import QtQuick

DesktopPopup {
    name: "menu"
    side: "left"
    compact: true
    gap: Tokens.spacing.small / 2

    PopupAction {
        text: "System information"
        onTriggered: Desktop.toggle("hardware")
    }
    PopupAction {
        text: Tokens.mode === "dark" ? "Switch to light theme" : "Switch to dark theme"
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["desktop-theme", "toggle"]);
        }
    }
    PopupAction {
        text: "Reload compositor"
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["shell-menu", "reload-compositor"]);
        }
    }
    PopupAction {
        text: "Open terminal"
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["shell-menu", "terminal"]);
        }
    }
    PopupAction {
        text: "Force quit ..."
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["shell-menu", "force-quit"]);
        }
    }
    PopupAction {
        text: "Open top"
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["shell-menu", "processes"]);
        }
    }
    PopupAction {
        text: Focused.app !== "" ? "Quit '" + Focused.app + "'" : "Quit focused window"
        onTriggered: {
            Desktop.closeAll();
            Desktop.run(["shell-menu", "quit"].concat(Focused.address === "" ? [] : [Focused.address]));
        }
    }
}
