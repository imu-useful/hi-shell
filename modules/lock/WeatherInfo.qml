import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Top right: small pills for the weather, the battery and the keyboard layout.
RowLayout {
    spacing: Appearance.space.sm

    component Pill: Tile {
        property string icon
        property string text
        implicitWidth: row.implicitWidth + Appearance.space.lg * 2
        implicitHeight: 40
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Appearance.space.sm
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; icon: parent.parent.icon; iconSize: 20; color: Colors.m3primary }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.text }
        }
    }

    Pill {
        visible: Weather.ready
        icon: Weather.icon
        text: `${Weather.temperature} · ${Weather.description}`
    }
    Pill {
        visible: Battery.available
        icon: Battery.icon
        text: `${Battery.percent}%`
    }
    Pill {
        visible: HyprlandXkb.code !== "" && HyprlandXkb.layout !== "error"
        icon: "keyboard"
        text: HyprlandXkb.code
    }
}
