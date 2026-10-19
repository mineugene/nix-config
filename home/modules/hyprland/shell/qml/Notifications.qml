pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification server. Every notification is kept in the history; toasts
// are only the recent ones, and none appear while do not disturb is on.
Singleton {
    id: root

    property bool dnd: false
    property var toasts: []
    property var arrived: ({})
    property real now: Date.now()

    readonly property var history: server.trackedNotifications
    readonly property int count: history.values.length

    function toggleDnd() {
        dnd = !dnd;
    }

    function hideToast(n) {
        toasts = toasts.filter(t => t !== n);
    }

    function dismissAll() {
        for (const n of history.values.slice())
            n.dismiss();
    }

    // A default action or a closing click ends the notification unless the
    // sender asked for it to stay.
    function activate(n, action) {
        if (action)
            action.invoke();
        if (n.resident)
            hideToast(n);
        else
            n.dismiss();
    }

    function age(n) {
        const seconds = Math.max(0, (now - (arrived[n.id] ?? now)) / 1000);
        if (seconds < 60)
            return "now";
        if (seconds < 3600)
            return Math.floor(seconds / 60) + "m ago";
        if (seconds < 86400)
            return Math.floor(seconds / 3600) + "h ago";
        return Math.floor(seconds / 86400) + "d ago";
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.arrived[n.id] = Date.now();
            if (!root.dnd)
                root.toasts = [n, ...root.toasts].slice(0, 5);
        }
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
