import QtQuick
import QtQuick.Effects
import qs.common
import qs.common.widgets

// The pieces a keynote slide is built from (see Keynote.qml): a soft colored glow, a device
// frame holding a picture, a bento tile and a counting number.
QtObject {
    // A soft blob of light (glow.frag)
    component Glow: ShaderEffect {
        property color tint: "white"
        property real strength: 0.5

        opacity: strength
        fragmentShader: Qt.resolvedUrl("glow.frag.qsb")
    }

    // A thin dark bezel with rounded corners around whatever is put inside (its screen), a shadow
    // under it and a glare that sweeps across once `glare` goes 0 -> 1
    component Device: Item {
        id: device

        default property alias content: screenContent.data
        property real glare: 0
        readonly property real corner: width * 0.018

        Rectangle {
            id: bezel
            anchors.fill: parent
            radius: device.corner + 6
            color: "#0c0c0e"
            border.color: "#3a3a40"
            border.width: 1.5
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 1
                shadowVerticalOffset: 30
                shadowOpacity: 0.9
                autoPaddingEnabled: true
            }
        }

        Item {
            id: screenArea
            anchors.fill: parent
            anchors.margins: 6

            Item {
                id: screenContent
                anchors.fill: parent
            }

            Rectangle {
                // The glare: a soft diagonal band of light
                width: parent.width * 0.35
                height: parent.height * 3
                anchors.verticalCenter: parent.verticalCenter
                x: -width + (parent.width + width * 2) * device.glare
                rotation: 25
                opacity: Math.sin(device.glare * Math.PI) * 0.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: screenMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        Rectangle {
            id: screenMask
            anchors.fill: screenArea
            radius: device.corner
            visible: false
            layer.enabled: true
        }
    }

    // A rounded dark card with a glyph, a title and a line under it
    component Tile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property color tint: "white"
        property real shown: 1
        property real unit: 12
        property real kick: 0
        // Which way it flips in (degrees around the vertical axis) and its clock for floating
        property real flipFrom: 75
        property real time: 0
        property real floatPhase: 0

        radius: unit * 2.4
        color: "#141416"
        border.color: Qt.rgba(1, 1, 1, 0.07)
        opacity: shown
        scale: (0.88 + 0.12 * shown) * (1 + 0.015 * kick)
        transform: [
            Rotation {
                origin.x: tile.width / 2
                origin.y: tile.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: tile.flipFrom * (1 - tile.shown)
            },
            Translate {
                y: (1 - tile.shown) * tile.unit * 4 + Math.sin(tile.time * 1.3 + tile.floatPhase) * tile.unit * 0.35 * tile.shown
            }
        ]

        // Light spilling from the icon over the tile, cut to the tile's rounded shape
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: tileMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Glow {
                x: tile.unit * 3.7 - width / 2
                y: tile.unit * 3.7 - height / 2
                width: Math.max(tile.width, tile.height) * 1.3
                height: tile.height * 1.5
                tint: tile.tint
                strength: 0.3 + 0.12 * tile.kick
            }
        }

        Rectangle {
            id: tileMask
            anchors.fill: parent
            radius: tile.radius
            visible: false
            layer.enabled: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: tile.unit * 2
            spacing: tile.unit * 0.5

            MaterialIcon {
                icon: tile.icon
                iconSize: tile.unit * 3.4
                fill: 1
                color: tile.tint
                bottomPadding: tile.unit * 0.8
            }

            Text {
                width: parent.width
                text: tile.title
                color: "white"
                font.family: Appearance.font.title
                font.pixelSize: tile.unit * 1.85
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: tile.subtitle
                color: "#9a9aa2"
                font.family: Appearance.font.title
                font.pixelSize: tile.unit * 1.2
                wrapMode: Text.WordWrap
            }
        }
    }

    // A big number that counts up to `value` while `progress` goes 0 -> 1, a label under it
    component Stat: Item {
        id: stat

        property real value: 0
        property real progress: 1
        property string suffix: ""
        property string label: ""
        property var colors: []
        property real size: 100
        property real time: 0
        property real kick: 0

        // 0 -> 1 with an overshoot, over the first part of the count
        readonly property real pop: {
            const c = Math.max(0, Math.min(1, progress * 3)), k = 2.2;
            return 1 + (k + 1) * Math.pow(c - 1, 3) + k * Math.pow(c - 1, 2);
        }
        readonly property real ring: Math.max(0, Math.min(1, progress * 1.6))

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight
        opacity: Math.min(1, progress * 4)

        Rectangle {
            anchors.centerIn: column
            anchors.verticalCenterOffset: -stat.size * 0.15
            width: stat.size * (0.6 + 2.6 * stat.ring)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, stat.size * 0.04 * (1 - stat.ring))
            border.color: Qt.alpha(stat.colors[1] ?? "white", 0.7 * (1 - stat.ring))
            visible: stat.progress > 0 && stat.ring < 1
        }

        Column {
            id: column
            spacing: stat.size * 0.08
            scale: 0.4 + 0.6 * stat.pop

            KeynoteText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(stat.value * stat.progress).toLocaleString(Qt.locale(), "f", 0) + stat.suffix
                size: stat.size
                weight: Font.Black
                colors: stat.colors
                time: stat.time
                kick: stat.kick
                shown: 1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.label
                color: "#a1a1a8"
                font.family: Appearance.font.title
                font.pixelSize: stat.size * 0.26
                font.weight: Font.Medium
                opacity: Math.max(0, Math.min(1, stat.progress * 3 - 0.5))
            }
        }
    }
}
