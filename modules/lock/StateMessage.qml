import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// Under the password pill: why the password was refused (flashes), or a hint about Caps Lock
// and the keyboard layout.
Item {
    id: root

    required property var pam

    readonly property string error: {
        if (pam.state === Pam.Error)
            return Translation.tr("Password check failed: %1").arg(pam.passwd.message);
        if (pam.lockMessage)
            return pam.lockMessage;
        if (pam.state === Pam.Failed)
            return Translation.tr("Incorrect password. Please try again.");
        if (pam.state === Pam.MaxTries)
            return Translation.tr("Maximum password attempts reached.");
        return "";
    }
    readonly property string hint: {
        const layout = HyprlandXkb.layout;
        const parts = [];
        if (pam.capsLock)
            parts.push(Translation.tr("Caps Lock is on"));
        if (layout !== "" && layout !== "error")
            parts.push(Translation.tr("Keyboard layout: %1").arg(layout));
        return parts.join(" · ");
    }

    implicitHeight: Math.max(message.implicitHeight, hintText.implicitHeight)

    onErrorChanged: {
        if (error !== "") {
            message.text = error;
            flash.restart();
        }
    }

    Connections {
        target: root.pam
        function onFlashMsg() {
            flash.restart();
        }
    }

    StyledText {
        id: hintText
        anchors.left: parent.left
        anchors.right: parent.right
        text: root.hint
        color: root.pam.capsLock ? Colors.m3tertiary : Colors.m3onSurfaceVariant
        font.pixelSize: Appearance.font.size.labelMedium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        opacity: root.error === "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.anim.fast } }
    }

    StyledText {
        id: message
        anchors.left: parent.left
        anchors.right: parent.right
        color: Colors.m3error
        font.pixelSize: Appearance.font.size.labelMedium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        opacity: root.error === "" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Appearance.anim.fast } }

        SequentialAnimation {
            id: flash
            NumberAnimation { target: message; property: "scale"; to: 1.08; duration: 80 }
            NumberAnimation { target: message; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutBack }
        }
    }
}
