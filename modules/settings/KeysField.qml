import QtQuick
import qs.common
import qs.common.widgets
import qs.services

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

    // Qt key -> the name Hyprland knows.
    readonly property var names: ({
        [Qt.Key_Space]: "Space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next",
        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
        [Qt.Key_Print]: "Print", [Qt.Key_Period]: "period", [Qt.Key_Comma]: "comma", [Qt.Key_Minus]: "minus",
        [Qt.Key_Equal]: "equal", [Qt.Key_Slash]: "slash", [Qt.Key_Backslash]: "backslash",
        [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_BracketLeft]: "bracketleft",
        [Qt.Key_BracketRight]: "bracketright", [Qt.Key_QuoteLeft]: "grave",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume", [Qt.Key_VolumeMute]: "XF86AudioMute",
        [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay", [Qt.Key_MediaNext]: "XF86AudioNext",
        [Qt.Key_MediaPrevious]: "XF86AudioPrev", [Qt.Key_MediaStop]: "XF86AudioStop",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_MicMute]: "XF86AudioMicMute"
    })
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_AltGr, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_CapsLock]

    // "SUPER + SHIFT + S" from a key event, or "" when it's only a modifier.
    function combo(event) {
        const k = event.key;
        if (modifierKeys.includes(k))
            return "";
        let name = names[k];
        if (name === undefined) {
            if (k >= Qt.Key_F1 && k <= Qt.Key_F35)
                name = "F" + (k - Qt.Key_F1 + 1);
            else if ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= Qt.Key_0 && k <= Qt.Key_9))
                name = String.fromCharCode(k);
            // Anything else (another layout's letters, shifted symbols): the key's code, which
            // Hyprland binds as code:N whatever the layout.
            else if (event.nativeScanCode > 0)
                name = `code:${event.nativeScanCode}`;
            else
                return "";
        }
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        return [...mods, name].join(" + ");
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
