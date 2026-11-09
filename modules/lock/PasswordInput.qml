import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The password pill: a lock icon, the typed characters as dots (each a different shape), and
// an enter button that appears once something is typed. It keeps the keyboard focus.
Rectangle {
    id: root

    required property var lock
    readonly property var pam: lock.pam
    readonly property bool typed: pam.buffer.length > 0
    readonly property bool busy: pam.passwd.active
    readonly property var dotShapes: ["slanted", "arch", "pentagon", "diamond", "triangle", "sunny", "cookie4", "softBurst", "flower", "hexagon", "star", "puffy"]

    implicitHeight: 56
    radius: Appearance.shape.field
    color: Appearance.translucent(Colors.m3surfaceContainerHigh)

    focus: true
    onActiveFocusChanged: {
        if (!activeFocus)
            forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (!root.lock.unlocking)
            pam.handleKey(event);
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.forceActiveFocus()
    }

    MaterialIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        icon: root.busy ? "progress_activity" : "lock"
        iconSize: 22
        color: root.pam.state === Pam.Failed ? Colors.m3error : Colors.m3onSurfaceVariant
        RotationAnimator on rotation {
            running: root.busy
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
        onIconChanged: if (!root.busy) rotation = 0
    }

    StyledText {
        anchors.centerIn: parent
        text: root.busy ? Translation.tr("Checking…")
            : root.pam.state === Pam.MaxTries ? Translation.tr("Max tries reached") : Translation.tr("Enter your password")
        color: root.busy ? Colors.m3secondary : Colors.m3outline
        opacity: root.typed ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Appearance.anim.fast } }
    }

    // The dots, centered: a typed character adds one shape on the right (it pops in) and the others slide left
    // to make room; backspace shrinks the last one away. A long password scrolls to its end.
    Item {
        id: dotArea
        anchors.left: icon.right
        anchors.right: enter.left
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        clip: true

        ListView {
            id: dots
            readonly property int cell: 22
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: Math.min(count * cell, dotArea.width)
            orientation: ListView.Horizontal
            interactive: false
            model: root.pam.buffer.length
            onCountChanged: positionViewAtEnd()

            Behavior on width { SpatialAnim {} }

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.spatialFast }
            }
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0; duration: Appearance.anim.fast }
            }

            delegate: Item {
                required property int index
                width: dots.cell
                height: dots.height

                MaterialShape {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    animated: false
                    shape: root.dotShapes[index % root.dotShapes.length]
                    color: Colors.m3onSurface
                }
            }
        }
    }

    Item {
        id: enter
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44

        MaterialShape {
            anchors.fill: parent
            shape: root.typed ? "circle" : "pill"
            color: root.typed ? Colors.m3primary : Appearance.translucent(Colors.m3surfaceContainerHighest)
            scale: root.typed ? (enterMouse.pressed ? 0.85 : 1) : 0.9
            Behavior on color { ColorAnim {} }
            Behavior on scale { SpringAnim { overshoot: 1.4 } }
        }
        MaterialIcon {
            anchors.centerIn: parent
            icon: "arrow_forward"
            iconSize: 22
            color: root.typed ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
        }
        MouseArea {
            id: enterMouse
            anchors.fill: parent
            enabled: root.typed && !root.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pam.passwd.start()
        }
    }
}
