import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Date and time (formats in bar.clock); click toggles the calendar popup. This pill is also the
// Dynamic Island: held for bar.island.holdDuration it draws a ring along its border and switches
// the island's state (Island.mode: the clock, or the music player) instead of opening the calendar.
// In the music state it shows the cover and the track, and a tap opens the player's controls.
// A notification (Island.notif) takes the pill over until it times out (a tap dismisses it); the
// camera / microphone indicator (PrivacyPill) sits at its start for as long as one is in use.
BarWidget {
    id: root

    readonly property var options: Config.options.bar.clock

    clickable: true
    active: ShellState.calendarOpen
    padding: 4
    readonly property bool music: Island.mode === "music"
    readonly property int artSize: thickness - 6
    property real closedAt: 0
    readonly property bool notifying: Island.notif !== null
    // Room for the privacy pill at the start (horizontal bars only).
    readonly property real lead: Privacy.active && !notifying && !vertical ? privacy.width + 8 : 0
    readonly property real baseWidth: music ? musicRow.implicitWidth + 6 : row.implicitWidth + 6
    contentWidth: vertical ? (music ? artSize : thickness)
                : notifying ? notification.implicitWidth - padding * 2 : baseWidth + lead
    contentHeight: music ? artSize : column.implicitHeight
    Behavior on contentWidth { SpatialAnim {} }
    onPressedDown: ShellState.startIslandHold()
    onPressedUp: ShellState.endIslandHold()
    onClicked: {
        if (!ShellState.islandHeld) {
            if (notifying)
                Notifications.hidePopup(Island.notif.uid);
            else if (music) {
                if (Date.now() - closedAt > 300)
                    Island.expanded = !Island.expanded;
            }
            else
                ShellState.calendarOpen = !ShellState.calendarOpen;
        }
        ShellState.islandHeld = false;
    }

    Connections {
        target: ShellState
        function onIslandSwitchesChanged() { pulse.restart(); }
    }

    SequentialAnimation {
        id: pulse
        NumberAnimation { target: root; property: "scale"; to: 1.06; duration: Appearance.anim.fast; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: Appearance.anim.normal; easing.type: Easing.OutBack }
    }

    HoldRing {
        parent: root
        anchors.fill: parent
        z: 10
        progress: ShellState.islandHold
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: row
        visible: !root.vertical && !root.music && !root.notifying
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        spacing: 8

        StyledText {
            Layout.leftMargin: 6
            text: clock.date.toLocaleString(Translation.locale, root.options.dateFormat)
            font.pixelSize: Appearance.font.size.normal
        }

        Rectangle {
            implicitWidth: time.implicitWidth + 16
            implicitHeight: root.thickness - 8
            radius: Appearance.rounding.full
            color: Colors.m3primary

            StyledText {
                id: time
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, root.options.timeFormat)
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Colors.m3onPrimary
            }
        }
    }

    ColumnLayout {
        id: column
        visible: root.vertical && !root.music && !root.notifying
        anchors.centerIn: parent
        spacing: -2

        Repeater {
            model: Qt.formatDateTime(clock.date, "HH mm").split(" ")

            StyledText {
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                text: modelData
                font.pixelSize: Appearance.font.size.bodyMedium
                font.weight: Font.DemiBold
            }
        }
    }

    // Music state: the cover, "title • artist", and the paused mark.
    RowLayout {
        id: musicRow
        visible: root.music && !root.notifying
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.lead / 2
        spacing: 8

        ShapeImage {
            Layout.preferredWidth: root.artSize
            Layout.preferredHeight: root.artSize
            shape: "cookie7"
            source: Mpris.artUrl
            opacity: Mpris.playing ? 1 : 0.6
        }

        StyledText {
            visible: !root.vertical
            Layout.maximumWidth: Config.options.bar.media.maxWidth
            text: Mpris.artist ? `${Mpris.title} • ${Mpris.artist}` : Mpris.title
            font.pixelSize: Appearance.font.size.normal
            elide: Text.ElideRight
        }

        MaterialIcon {
            visible: !root.vertical && !Mpris.playing
            icon: "pause"
            fill: 1
            iconSize: 16
            color: Colors.m3onSurfaceVariant
        }
    }

    PrivacyPill {
        id: privacy
        visible: Privacy.active && !root.notifying && !root.vertical
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    IslandNotification {
        id: notification
        parent: root
        anchors.fill: parent
        visible: root.notifying
        compact: root.vertical
    }

    // A tap in the music state opens the player's controls under the island.
    StyledPopup {
        target: root
        id: musicPopup
        pinned: Island.musicExpanded
        edge: root.popupEdge

        MediaControls {}
    }

    // A click anywhere else closes the player's controls. The tap on the island itself comes after
    // this clears the grab; it would reopen them, hence the guard in onClicked.
    HyprlandFocusGrab {
        windows: [musicPopup]
        active: Island.musicExpanded && musicPopup.visible
        onCleared: {
            Island.expanded = false;
            closedAt = Date.now();
        }
    }
}
