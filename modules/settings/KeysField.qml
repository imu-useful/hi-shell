import QtQuick
import qs.common
import qs.common.widgets
import qs.services
import "KeyNames.js" as KeyNames

// A field for a keybind's keys ("SUPER + SHIFT + S"): typed by hand, or recorded: the keyboard
// button waits for the shortcut and writes it in the way Hyprland takes it. While it waits Hyprland's
// own keybinds are off (the empty "hi-wait" submap), or Super + V would run its bind instead of
// reaching the field; Esc, a click elsewhere or a few seconds end it.
Rectangle {
    id: root

    property string value: ""
    property string placeholder: ""
    property bool readOnly: false
    property bool recording: false
    signal edited(string keys)

    implicitWidth: 260
    implicitHeight: 36
    radius: 18
    color: recording ? Colors.m3primaryContainer : Colors.m3surfaceContainerHighest
    border.width: field.activeFocus ? 2 : 0
    border.color: Colors.m3primary

    function combo(event) {
        return KeyNames.combo(event.key, event.modifiers, event.nativeScanCode);
    }

    function startRecording() {
        if (readOnly)
            return;
        recording = true;
        HyprlandSettings.apply('hl.dispatch(hl.dsp.submap("hi-wait"))');
        field.forceActiveFocus();
        giveUp.restart();
    }

    function stopRecording() {
        if (!recording)
            return;
        recording = false;
        giveUp.stop();
        HyprlandSettings.apply('hl.dispatch(hl.dsp.submap("reset"))');
    }

    // Never leave Hyprland's binds off.
    Timer {
        id: giveUp
        interval: 8000
        onTriggered: root.stopRecording()
    }
    Component.onDestruction: stopRecording()

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 40
        verticalAlignment: TextInput.AlignVCenter
        text: root.value
        readOnly: root.readOnly || root.recording
        font.family: Appearance.font.main
        font.pixelSize: Appearance.font.size.bodyMedium
        color: Colors.m3onSurface
        clip: true
        selectByMouse: true
        onAccepted: {
            root.edited(text.trim());
            focus = false;
        }
        onActiveFocusChanged: {
            if (!activeFocus) {
                root.stopRecording();
                if (text.trim() !== root.value && text.trim() !== "")
                    root.edited(text.trim());
            }
        }

        Keys.onPressed: event => {
            if (!root.recording)
                return;
            event.accepted = true;
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                root.stopRecording();
                return;
            }
            const keys = root.combo(event);
            if (keys === "")
                return;
            root.stopRecording();
            root.edited(keys);
            focus = false;
        }

        StyledText {
            anchors.fill: parent
            visible: field.text === "" || root.recording
            text: root.recording ? Translation.tr("Press the shortcut… (Esc cancels)") : root.placeholder
            color: root.recording ? Colors.m3onPrimaryContainer : Colors.m3outline
            elide: Text.ElideRight
        }
    }

    // The keyboard button.
    Item {
        visible: !root.readOnly
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30

        MaterialIcon {
            anchors.centerIn: parent
            icon: root.recording ? "close" : "keyboard"
            iconSize: 18
            color: root.recording ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
        }
        StateLayer {
            radius: 15
            onClicked: root.recording ? root.stopRecording() : root.startRecording()
        }
    }
}
