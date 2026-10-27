import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// The Wait Mode cover of one screen: a full-screen overlay that takes the keyboard and the
// pointer. In bypass (see shell.qml) it's invisible, takes no input and gives the keyboard
// back, so automated tests can see and click what's underneath.
PanelWindow {
    id: win

    required property var modelData
    required property var control

    readonly property real unit: Math.min(width, height)

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // An empty region takes no input at all.
    mask: control.bypass ? noInput : null
    Region { id: noInput }

    WlrLayershell.namespace: "hi-wait-mode"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: control.bypass ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    // No dimming, locking or sleeping while it's on.
    IdleInhibitor {
        window: win
        enabled: true
    }

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // Esc three times (within a few seconds) ends it; everything else goes nowhere.
            if (event.key === Qt.Key_Escape && !event.isAutoRepeat)
                win.control.pressEsc();
            event.accepted = true;
        }

        // Everything the person sees.
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: win.control.bypass ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // The wallpaper, blurred and dimmed.
            Image {
                id: wall
                anchors.fill: parent
                visible: false
                source: Theme.wallpaper ? `file://${Theme.wallpaper}` : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width / 2, win.height / 2)
            }
            MultiEffect {
                anchors.fill: parent
                visible: Theme.wallpaper !== ""
                source: wall
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.3
                saturation: -0.15
            }

            Loader {
                anchors.fill: parent
                sourceComponent: win.control.hasMusic ? music : frame
            }

            // Esc x 3: three dots that fill up.
            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: win.unit * 0.05
                spacing: 10

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 12
                            height: 12
                            radius: 6
                            color: index < win.control.escapes ? Theme.primary : "transparent"
                            border.width: 2
                            border.color: index < win.control.escapes ? Theme.primary : Theme.outline
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.tr("Press Esc three times to exit", "Нажмите Esc три раза, чтобы выйти")
                    color: Theme.muted
                    font.pixelSize: Math.max(14, win.unit * 0.018)
                }
            }
        }
    }

    // --- Music: the cover, the title and artist, the progress ---
    Component {
        id: music

        Item {
            readonly property var player: win.control.player
            readonly property real cover: win.unit * 0.42

            ColumnLayout {
                anchors.centerIn: parent
                spacing: win.unit * 0.025

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.tr("Wait Mode", "Режим ожидания")
                    color: Theme.primary
                    font.pixelSize: Math.max(14, win.unit * 0.02)
                    font.weight: Font.Medium
                    font.letterSpacing: 2
                }
                RoundedImage {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: cover
                    implicitHeight: cover
                    radius: cover * 0.08
                    source: player?.trackArtUrl ?? ""
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: win.width * 0.8
                    text: player?.trackTitle ?? ""
                    color: Theme.text
                    elide: Text.ElideRight
                    font.pixelSize: win.unit * 0.045
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: win.width * 0.8
                    text: player?.trackArtist ?? ""
                    color: Theme.muted
                    elide: Text.ElideRight
                    font.pixelSize: win.unit * 0.028
                }
                // Progress (shown, not to be moved).
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: cover
                    visible: (player?.length ?? 0) > 0
                    spacing: 12
                    Text {
                        text: win.time(player?.position ?? 0)
                        color: Theme.muted
                        font.pixelSize: win.unit * 0.018
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surface
                        Rectangle {
                            width: parent.width * Math.min(1, (player?.position ?? 0) / Math.max(1, player?.length ?? 1))
                            height: parent.height
                            radius: 3
                            color: Theme.primary
                        }
                    }
                    Text {
                        text: win.time(player?.length ?? 0)
                        color: Theme.muted
                        font.pixelSize: win.unit * 0.018
                    }
                }
            }
        }
    }

    // --- No music: the wallpaper in a frame, with the name of the mode ---
    Component {
        id: frame

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: win.unit * 0.04

                RoundedImage {
                    id: picture
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: win.unit * 0.5
                    implicitHeight: win.unit * 0.5
                    radius: win.unit * 0.12
                    source: Theme.wallpaper ? `file://${Theme.wallpaper}` : ""

                    // A thin outline, so the frame shows against a dark wallpaper.
                    Rectangle {
                        anchors.fill: parent
                        radius: picture.radius
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.alpha(Theme.primary, 0.6)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.tr("Wait Mode", "Режим ожидания")
                    color: Theme.text
                    font.pixelSize: win.unit * 0.06
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
