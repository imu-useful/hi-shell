import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// The card: the weather, system info and player on the left; the clock, avatar and password in
// the middle; the resources and notifications on the right.
RowLayout {
    id: root

    required property var lock
    readonly property real scaleFactor: Math.min(1, (lock.screen?.height ?? 1440) / 1440)

    spacing: Appearance.space.xl

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        spacing: Appearance.space.md

        WeatherInfo { Layout.fillWidth: true }
        Fetch { Layout.fillWidth: true }
        Media { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    Center {
        lock: root.lock
        scaleFactor: root.scaleFactor
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        spacing: Appearance.space.md

        Resources { Layout.fillWidth: true }
        NotifDock { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
