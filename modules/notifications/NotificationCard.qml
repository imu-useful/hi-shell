import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// One notification: icon / image, app + time, summary, body (click to expand),
// actions and inline reply. As a popup it shows a countdown bar that pauses on
// hover. Swipe sideways, right click (or the close button) to dismiss.
Item {
    id: root

    required property var notif
    property bool popup: false
    property bool expanded: false

    // Icon-theme images ("image://icon/<name>", e.g. from notify-send -i) render a
    // checkerboard when the icon is missing, so only use them if the theme has them.
    readonly property string imageSource: {
        const image = notif.image;
        if (image.startsWith("image://icon/"))
            return Quickshell.iconPath(image.slice(13), true);
        return image;
    }
    readonly property bool hasImage: imageSource !== ""
    readonly property string appIconSource: {
        const icon = notif.appIcon;
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.includes("://"))
            return icon.startsWith("/") ? "file://" + icon : icon;
        return Quickshell.iconPath(icon, true);
    }

    // Erase animation (EraseAnim): slides away and fades (leave), then the row folds (collapse).
    property real leave: 0
    property real collapse: 1
    // -1 / 1: the side it leaves to (the way it was swiped).
    property int leaveDir: 1
    readonly property var eraseDelay: Notifications.erasing[notif.uid]

    implicitWidth: 380
    implicitHeight: card.implicitHeight * collapse
    clip: leave > 0

    // The notification is removed once the animation is over (Notifications.erase).
    function dismiss() {
        leaveDir = card.x < 0 ? -1 : 1;
        Notifications.erase([notif.uid]);
    }

    onEraseDelayChanged: {
        if (eraseDelay !== undefined && !eraser.running) {
            eraser.delay = eraseDelay;
            eraser.start();
        }
    }
    EraseAnim {
        id: eraser
        target: root
    }

    Rectangle {
        id: card

        width: parent.width
        implicitHeight: content.implicitHeight + 28
        radius: Appearance.shape.card
        color: root.popup ? Colors.m3surfaceContainer : Appearance.translucent(Colors.m3surfaceContainerLow)
        border.width: Math.max(1, Appearance.edge)
        border.color: root.notif.critical ? Colors.m3error : hover.hovered ? Colors.m3outline : Colors.m3outlineVariant
        Behavior on border.color { ColorAnim {} }
        opacity: (1 - Math.min(0.8, Math.abs(x) / width)) * (1 - root.leave)
        transform: Translate { x: root.leaveDir * root.leave * card.width * 0.5 }

        Behavior on x {
            enabled: !drag.active
            SpatialAnim {}
        }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                root.notif.paused = hovered || reply.activeFocus;
                if (root.notif.notification?.hasInlineReply)
                    Notifications.replyHover = hovered ? root.notif : (Notifications.replyHover === root.notif ? null : Notifications.replyHover);
            }
        }
        Component.onDestruction: if (Notifications.replyHover === root.notif) Notifications.replyHover = null

        // Swipe to dismiss.
        DragHandler {
            id: drag
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    return;
                if (Math.abs(card.x) > card.width * 0.35)
                    root.dismiss();
                else
                    card.x = 0;
            }
        }

        // Click the body = default action (most apps focus their window).
        TapHandler {
            onTapped: {
                if (root.notif.actions.some(a => a.identifier === "default"))
                    Notifications.invoke(root.notif.uid, "default");
                else
                    root.expanded = !root.expanded;
            }
        }

        // Right click = dismiss.
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.dismiss()
        }

        // A bar down the left side, like a marked log line: the accent, red when critical.
        Rectangle {
            width: 3
            height: parent.height
            topLeftRadius: parent.radius
            bottomLeftRadius: parent.radius
            color: root.notif.critical ? Colors.m3error : Colors.m3primary
        }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 16
            spacing: 12

            // Image (contact photo, album art) with the app icon as a badge, or just the app icon.
            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40

                ShapeImage {
                    anchors.fill: parent
                    visible: root.hasImage
                    shape: "box"
                    source: root.imageSource
                }

                Rectangle {
                    visible: !root.hasImage
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: "transparent"
                    border.width: 1
                    border.color: root.notif.critical ? Colors.m3error : Colors.m3outlineVariant

                    IconImage {
                        id: bigIcon
                        anchors.centerIn: parent
                        implicitSize: 26
                        source: root.appIconSource
                        visible: status === Image.Ready
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !bigIcon.visible
                        icon: root.notif.critical ? "priority_high" : "notifications"
                        color: root.notif.critical ? Colors.m3error : Colors.m3onSurfaceVariant
                    }
                }

                IconImage {
                    visible: root.hasImage && root.appIconSource !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -2
                    implicitSize: 18
                    source: root.appIconSource
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MonoLabel {
                        Layout.maximumWidth: content.width * 0.5
                        text: root.notif.appName
                        color: root.notif.critical ? Colors.m3error : Colors.m3primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Notifications.relativeTime(root.notif.time)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3outline
                    }
                    MaterialIcon {
                        visible: root.notif.body.length > 0
                        icon: root.expanded ? "expand_less" : "expand_more"
                        iconSize: 18
                    }
                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: Appearance.shape.button
                        color: "transparent"
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "close"
                            iconSize: 16
                        }
                        StateLayer {
                            onClicked: root.dismiss()
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notif.summary
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? 4 : 1
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notif.body
                    textFormat: Text.StyledText
                    font.pixelSize: Appearance.font.size.labelMedium + 1
                    color: Colors.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? 12 : 2
                    linkColor: Colors.m3primary
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                // Actions ("default" is the body click, not a button).
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: buttons.count > 0
                    spacing: 6

                    Repeater {
                        id: buttons
                        model: root.notif.actions.filter(a => a.identifier !== "default" && a.text)

                        Chip {
                            required property var modelData
                            text: modelData.text
                            onClicked: Notifications.invoke(root.notif.uid, modelData.identifier)
                        }
                    }
                }

                // Inline reply (messengers).
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: root.notif.notification?.hasInlineReply ?? false
                    implicitHeight: 34
                    radius: Appearance.shape.field
                    color: "transparent"
                    border.width: Math.max(1, Appearance.edge)
                    border.color: reply.activeFocus ? Colors.m3primary : Colors.m3outlineVariant

                    TextInput {
                        id: reply
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 40
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Appearance.font.main
                        font.pixelSize: Appearance.font.size.bodyMedium
                        color: Colors.m3onSurface
                        clip: true
                        // The popup stays while you're typing, not only while the pointer is on it.
                        onActiveFocusChanged: {
                            root.notif.paused = hover.hovered || activeFocus;
                            Notifications.replying = activeFocus;
                        }
                        Keys.onEscapePressed: focus = false
                        onAccepted: if (text.trim()) Notifications.reply(root.notif.uid, text)

                        StyledText {
                            anchors.fill: parent
                            visible: reply.text === ""
                            text: root.notif.notification?.inlineReplyPlaceholder || Translation.tr("Reply")
                            color: Colors.m3outline
                        }
                    }
                    MaterialIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "send"
                        iconSize: 18
                        color: Colors.m3primary
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: reply.accepted()
                        }
                    }
                }
            }
        }

        // Countdown until the popup hides (it stays in the history).
        Rectangle {
            visible: root.popup && root.notif.timeout > 0
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 1
            anchors.leftMargin: 3
            width: (parent.width - 4) * root.notif.remaining
            // The countdown ticks 20 times a second; smooth out the steps.
            Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.Linear } }
            height: 2
            color: Qt.alpha(Colors.m3primary, 0.7)
        }
    }
}
