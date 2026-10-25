import QtQuick
import Quickshell
import qs.common

// Creates a panel's window only while it is shown and destroys it after the
// close animation, so closed panels cost no memory or rendering.
//
// Bind open/close animations to `revealed`, not to `shown`: it turns true just
// after the window is created, so the open animation also plays on a fresh window.
LazyLoader {
    id: root

    property bool shown: false
    // How long the window outlives `shown` going false (covers the close animation).
    property int closeDelay: Appearance.anim.spatial + 50
    property bool revealed: false

    property Timer keepAlive: Timer {
        interval: root.closeDelay
    }

    active: shown || keepAlive.running

    onShownChanged: {
        if (shown) {
            keepAlive.stop();
            Qt.callLater(() => root.revealed = root.shown);
        } else {
            revealed = false;
            keepAlive.restart();
        }
    }
}
