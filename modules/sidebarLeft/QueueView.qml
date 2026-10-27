import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Spotify's queue in the player card: sign-in, the queue, and a search to add tracks.
// Replaces the lyrics while it's open (see HomePage).
ColumnLayout {
    id: root

    readonly property bool searchingNow: search.text.trim() !== ""

    spacing: 8

    Component.onCompleted: SpotifyQueue.users++
    Component.onDestruction: SpotifyQueue.users--

    // --- Not set up / signed out / error ---
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: SpotifyQueue.status !== "ok"
        spacing: 10

        Item { Layout.fillHeight: true }

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: SpotifyQueue.status === "error" ? "error" : "queue_music"
            iconSize: 36
            color: SpotifyQueue.status === "error" ? Colors.m3error : Colors.m3onSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: SpotifyQueue.connecting ? (SpotifyQueue.authNote || Translation.tr("Finish signing in in your browser…"))
                : !SpotifyQueue.configured ? Translation.tr("Put the Spotify Client ID in Settings › Services")
                : SpotifyQueue.status === "needs_auth" ? Translation.tr("Connect Spotify to see and add to the queue")
                : SpotifyQueue.status === "error" ? SpotifyQueue.message
                : Translation.tr("Loading…")
            color: Colors.m3onSurfaceVariant
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            M3Button {
                visible: !SpotifyQueue.configured
                icon: "settings"
                text: Translation.tr("Settings")
                onClicked: {
                    ShellState.settingsPage = "services";
                    ShellState.settingsOpen = true;
                }
            }
            M3Button {
                visible: SpotifyQueue.configured && !SpotifyQueue.connecting && SpotifyQueue.status !== "idle"
                icon: SpotifyQueue.status === "error" ? "refresh" : "login"
                text: SpotifyQueue.status === "error" ? Translation.tr("Try again") : Translation.tr("Connect Spotify")
                onClicked: SpotifyQueue.status === "error" ? SpotifyQueue.refresh() : SpotifyQueue.connect()
            }
            M3Button {
                visible: SpotifyQueue.status === "error" && SpotifyQueue.configured && !SpotifyQueue.connecting
                tonal: true
                icon: "login"
                text: Translation.tr("Reconnect")
                onClicked: SpotifyQueue.connect()
            }
            M3Button {
                visible: SpotifyQueue.connecting
                tonal: true
                icon: "close"
                text: Translation.tr("Cancel")
                onClicked: SpotifyQueue.cancelConnect()
            }
            // When the browser didn't open: the address to open by hand.
            M3Button {
                visible: SpotifyQueue.connecting && SpotifyQueue.authUrl !== ""
                icon: "content_copy"
                text: Translation.tr("Copy link")
                onClicked: Quickshell.clipboardText = SpotifyQueue.authUrl
            }
        }

        Item { Layout.fillHeight: true }
    }

    // --- Signed in ---
    RowLayout {
        Layout.fillWidth: true
        visible: SpotifyQueue.status === "ok"
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 18
            color: Colors.m3surfaceContainerHighest
            border.width: search.activeFocus ? 2 : 0
            border.color: Colors.m3primary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 6

                MaterialIcon {
                    icon: "search"
                    iconSize: 18
                    color: Colors.m3onSurfaceVariant
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.main
                    font.pixelSize: Appearance.font.size.bodyMedium
                    color: Colors.m3onSurface
                    clip: true
                    selectByMouse: true
                    onTextChanged: searchTimer.restart()

                    StyledText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: Translation.tr("Search a track to add")
                        color: Colors.m3outline
                    }
                }
                IconButton {
                    visible: search.text !== ""
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "close"
                    onClicked: search.text = ""
                }
            }
        }
        IconButton {
            icon: "refresh"
            enabled: !SpotifyQueue.loading
            onClicked: SpotifyQueue.refresh()
        }
        IconButton {
            icon: "logout"
            tooltip: Translation.tr("Disconnect")
            onClicked: SpotifyQueue.disconnect()
        }
    }

    // Typing waits a moment before it searches.
    Timer {
        id: searchTimer
        interval: 450
        onTriggered: SpotifyQueue.search(search.text)
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: SpotifyQueue.status === "ok"
        clip: true
        spacing: 4
        // The search results, or "now playing" followed by what's next.
        model: root.searchingNow ? SpotifyQueue.results
            : (SpotifyQueue.playing ? [Object.assign({ playing: true }, SpotifyQueue.playing)] : []).concat(SpotifyQueue.queue)

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: list.width
            height: 48
            radius: Appearance.rounding.medium
            color: modelData.playing ? Colors.m3secondaryContainer : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 10

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 8
                    color: Colors.m3surfaceContainerHighest
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: row.modelData.art ?? ""
                        sourceSize: Qt.size(72, 72)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.weight: row.modelData.playing ? Font.DemiBold : Font.Normal
                        color: row.modelData.playing ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.artists
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: row.modelData.playing ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                    }
                }
                MaterialIcon {
                    visible: !!row.modelData.playing
                    icon: "graphic_eq"
                    iconSize: 20
                    color: Colors.m3primary
                }
                IconButton {
                    visible: root.searchingNow
                    implicitWidth: 34
                    implicitHeight: 34
                    icon: "playlist_add"
                    tooltip: Translation.tr("Add to the queue")
                    onClicked: SpotifyQueue.add(row.modelData.uri)
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.searchingNow ? (SpotifyQueue.searching ? Translation.tr("Searching…") : Translation.tr("Nothing found"))
                : SpotifyQueue.loading ? Translation.tr("Loading…") : Translation.tr("The queue is empty")
            color: Colors.m3outline
        }
    }
}
