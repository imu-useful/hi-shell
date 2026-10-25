import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Greeting, now playing with synced lyrics, weather.
ColumnLayout {
    id: root

    spacing: 12

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- Greeting ---
    Card {
        Layout.fillWidth: true
        implicitHeight: 96
        baseColor: Colors.m3surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            ShapeImage {
                implicitWidth: 62
                implicitHeight: 62
                shape: "cookie12"
                source: `file://${Paths.home}/.face`
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    readonly property int hour: clock.date.getHours()
                    text: `${hour < 5 ? Translation.tr("Good night") : hour < 12 ? Translation.tr("Good morning") : hour < 18 ? Translation.tr("Good afternoon") : Translation.tr("Good evening")}, ${Quickshell.env("USER")}!`
                    font.pixelSize: Appearance.font.size.titleLarge
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: clock.date.toLocaleDateString(Translation.locale, "dddd, d MMMM") + (Todo.pending ? " · " + Translation.trn("%1 task", "%1 tasks", Todo.pending) : "")
                    color: Colors.m3onSurfaceVariant
                }
            }
        }
    }

    // --- Now playing + lyrics ---
    Card {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Mpris.hasPlayer
        baseColor: Colors.m3surfaceContainer
        clip: true

        Component.onCompleted: Lyrics.users++
        Component.onDestruction: Lyrics.users--

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                ShapeImage {
                    implicitWidth: 96
                    implicitHeight: 96
                    shape: "square"
                    source: Mpris.artUrl
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Mpris.title
                        font.pixelSize: Appearance.font.size.titleMedium
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Mpris.artist
                        color: Colors.m3onSurfaceVariant
                    }
                    RowLayout {
                        spacing: 4
                        IconButton {
                            icon: "skip_previous"
                            onClicked: Mpris.previous()
                        }
                        IconButton {
                            implicitWidth: 52
                            filled: true
                            icon: Mpris.playing ? "pause" : "play_arrow"
                            onClicked: Mpris.togglePlaying()
                        }
                        IconButton {
                            icon: "skip_next"
                            onClicked: Mpris.next()
                        }
                        Item { Layout.fillWidth: true }
                        IconButton {
                            visible: Mpris.players.length > 1
                            icon: "swap_horiz"
                            onClicked: Mpris.cyclePlayer()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Mpris.length > 0
                spacing: 10

                StyledText {
                    text: Mpris.formatTime(Mpris.position)
                    font.pixelSize: Appearance.font.size.labelSmall
                    font.features: { "tnum": 1 }
                    color: Colors.m3onSurfaceVariant
                }
                M3Slider {
                    playback: true
                    Layout.fillWidth: true
                    implicitHeight: 22
                    value: Mpris.progress
                    onMoved: value => Mpris.seekTo(value)
                }
                StyledText {
                    text: Mpris.formatTime(Mpris.length)
                    font.pixelSize: Appearance.font.size.labelSmall
                    font.features: { "tnum": 1 }
                    color: Colors.m3onSurfaceVariant
                }
            }

            // Lyrics: current line bright and centered, the rest dimmed.
            ListView {
                id: lyrics
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: !Lyrics.synced
                model: Lyrics.lines
                currentIndex: Lyrics.index
                highlightRangeMode: Lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
                preferredHighlightBegin: height / 2 - 18
                preferredHighlightEnd: height / 2 + 18
                highlightMoveDuration: Appearance.anim.slow
                spacing: 6

                delegate: StyledText {
                    required property var modelData
                    required property int index
                    readonly property bool current: index === Lyrics.index
                    readonly property int distance: Math.abs(index - Lyrics.index)

                    width: lyrics.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    text: modelData.text || "♪"
                    font.pixelSize: current ? Appearance.font.size.titleMedium : Appearance.font.size.bodyMedium
                    font.weight: current ? Font.DemiBold : Font.Normal
                    color: current ? Colors.m3primary : Colors.m3onSurfaceVariant
                    opacity: !Lyrics.synced || current ? 1 : Math.max(0.3, 0.8 - distance * 0.12)

                    Behavior on opacity { EffectAnim {} }

                    MouseArea {
                        anchors.fill: parent
                        enabled: Lyrics.synced && Mpris.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        // Click a line to jump there.
                        onClicked: Mpris.seekTo(parent.modelData.time / Mpris.length)
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: Lyrics.lines.length === 0
                    text: Lyrics.loading ? Translation.tr("Looking for lyrics…") : Lyrics.status === "error" ? Translation.tr("Couldn't load lyrics") : Translation.tr("No lyrics found")
                    color: Colors.m3outline
                }
            }
        }
    }

    // --- Weather ---
    Card {
        Layout.fillWidth: true
        visible: Weather.ready
        implicitHeight: 88
        baseColor: Colors.m3surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: 28
                color: Colors.m3tertiaryContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Weather.icon
                    fill: 1
                    iconSize: 30
                    color: Colors.m3onTertiaryContainer
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: `${Weather.temperature} · ${Weather.description}`
                    font.pixelSize: Appearance.font.size.titleMedium
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.ready ? Translation.tr("%1 · feels like %2° · %3% humidity").arg(Weather.city).arg(Math.round(Weather.current.feelsLike)).arg(Weather.current.humidity) : ""
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            ColumnLayout {
                spacing: 0
                visible: Weather.daily.length > 0
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Weather.daily.length ? `↑ ${Math.round(Weather.daily[0].max)}°` : ""
                    font.pixelSize: Appearance.font.size.labelMedium
                }
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Weather.daily.length ? `↓ ${Math.round(Weather.daily[0].min)}°` : ""
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
        }
    }

    // Fills the space when nothing is playing.
    Item {
        Layout.fillHeight: true
        visible: !Mpris.hasPlayer
    }
}
