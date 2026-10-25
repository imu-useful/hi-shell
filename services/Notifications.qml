pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.common

// Notification daemon (org.freedesktop.Notifications): popups, history kept
// across restarts, do-not-disturb. Only one daemon can own the bus name; if
// another one (mako, dunst, illogical-impulse) runs, hi-shell gets nothing.
// IPC: `qs -c hi-shell ipc call notifications toggleDnd` (clear, list, dismiss <uid>).
Singleton {
    id: root

    readonly property var options: Config.options.notifications

    // Newest first.
    property list<QtObject> list: []
    readonly property list<QtObject> popups: list.filter(n => n.popup)
    readonly property int unread: list.filter(n => !n.read).length
    property bool dnd: false
    property int nextId: 1

    component Notif: QtObject {
        id: notif

        property int uid
        // The live notification; null once the sender is gone or after a restart.
        property Notification notification: null
        property string appName: ""
        property string appIcon: ""
        property string summary: ""
        property string body: ""
        property string image: ""
        property int urgency: NotificationUrgency.Normal
        property real time: Date.now()
        // [{ identifier, text }]
        property var actions: []
        property bool popup: false
        property bool read: false
        property int timeout: 0 // ms; 0 = stays until dismissed

        readonly property bool critical: urgency === NotificationUrgency.Critical

        // Popup countdown; pauses while the pointer is over the popup.
        property bool paused: false
        property real elapsed: 0
        readonly property real remaining: timeout > 0 ? Math.max(0, 1 - elapsed / timeout) : 1 // 1..0

        property Timer expiry: Timer {
            interval: 50
            repeat: true
            running: notif.popup && notif.timeout > 0 && !notif.paused
            onTriggered: {
                notif.elapsed += interval;
                if (notif.elapsed >= notif.timeout)
                    notif.popup = false;
            }
        }

        property Connections source: Connections {
            target: notif.notification
            // The app withdrew it (CloseNotification) or it was dismissed.
            function onClosed(reason) {
                notif.notification = null;
                notif.actions = [];
                notif.popup = false;
            }
        }
    }

    Component {
        id: notifComponent
        Notif {}
    }

    function add(n) {
        n.tracked = true;
        // Replacing an existing notification (same app re-sending with replaces_id).
        const existing = list.find(x => x.notification === n);
        const item = existing ?? notifComponent.createObject(root, { uid: nextId++ });
        item.notification = n;
        item.appName = n.appName || "Unknown";
        item.appIcon = n.appIcon;
        item.summary = n.summary;
        item.body = n.body;
        item.image = n.image;
        item.urgency = n.urgency;
        item.time = Date.now();
        item.actions = n.actions.map(a => ({ identifier: a.identifier, text: a.text }));
        item.timeout = n.urgency === NotificationUrgency.Critical || n.expireTimeout === 0 ? 0
                     : n.expireTimeout > 0 ? n.expireTimeout : options.defaultTimeout;
        item.read = false;
        item.elapsed = 0;
        item.popup = !dnd || item.critical;
        if (!existing)
            list = [item, ...list].slice(0, Math.max(1, options.historyLimit));
        save();
    }

    function find(uid) {
        return list.find(n => n.uid === uid) ?? null;
    }

    // Hide the popup; the notification stays in the history.
    function hidePopup(uid) {
        const n = find(uid);
        if (n)
            n.popup = false;
    }

    // Remove from history and tell the sender it was dismissed.
    function dismiss(uid) {
        const n = find(uid);
        if (!n)
            return;
        n.notification?.dismiss();
        list = list.filter(x => x !== n);
        n.destroy();
        save();
    }

    function clear() {
        for (const n of list) {
            n.notification?.dismiss();
            n.destroy();
        }
        list = [];
        save();
    }

    // Run an action ("default" = clicking the notification body).
    function invoke(uid, identifier) {
        const n = find(uid);
        const action = n?.notification?.actions.find(a => a.identifier === identifier);
        if (action) {
            action.invoke();
        }
        if (n && !n.notification?.resident)
            dismiss(uid);
    }

    function reply(uid, text) {
        const n = find(uid);
        if (n?.notification?.hasInlineReply)
            n.notification.sendInlineReply(text);
        dismiss(uid);
    }

    function markAllRead() {
        for (const n of list)
            n.read = true;
    }

    // "now", "5m", "2h", "Mon"
    function relativeTime(time) {
        const s = (Date.now() - time) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return Translation.tr("%1m").arg(Math.floor(s / 60));
        if (s < 86400)
            return Translation.tr("%1h").arg(Math.floor(s / 3600));
        return new Date(time).toLocaleDateString(Translation.locale, "ddd");
    }

    function save() {
        saveTimer.restart();
    }

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: n => root.add(n)
    }

    // History (without live actions) in ~/.local/state/hi-shell/notifications.json.
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: store.setText(JSON.stringify({
            dnd: root.dnd,
            notifications: root.list.map(n => ({
                appName: n.appName,
                appIcon: n.appIcon,
                summary: n.summary,
                body: n.body,
                // Images served by the notification server don't survive a restart.
                image: n.image.startsWith("image://") ? "" : n.image,
                urgency: n.urgency,
                time: n.time,
                read: n.read
            }))
        }, null, 1))
    }

    onDndChanged: save()

    FileView {
        id: store
        path: Paths.state + "/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.dnd = data.dnd ?? false;
                const restored = (data.notifications ?? []).map(n => notifComponent.createObject(root, Object.assign({ uid: root.nextId++ }, n)));
                root.list = [...root.list, ...restored];
            } catch (e) {
                console.warn("Notifications: invalid history file", e);
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function clear(): void {
            root.clear();
        }
        // One "uid<TAB>app<TAB>summary" line per notification, newest first.
        function list(): string {
            return root.list.map(n => `${n.uid}\t${n.appName}\t${n.summary}`).join("\n");
        }
        function dismiss(uid: int): void {
            root.dismiss(uid);
        }
    }
}
