import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Version, components, links.
ColumnLayout {
    id: root

    property string revision: ""
    readonly property string shellStatus: Updates.shellChecking ? Translation.tr("Checking…")
        : Updates.shellBehind > 0 ? Translation.trn("%1 new change", "%1 new changes", Updates.shellBehind).arg(Updates.shellBehind)
        : Updates.shellBehind === 0 ? Translation.tr("Up to date")
        : Translation.tr("Couldn't check for updates (no network?)")
    property string quickshell: ""

    // Easter egg: five taps on the logo open the secret setting
    readonly property int secretTaps: 5
    readonly property var secretKeys: ["hi", "matrix", "confetti", "sudo", "arch", "42", "disco", "nyan", "man", "egg", "undertale", "story", "mania", "osu", "material", "material you", "m3", "expressive", "liquid glass", "liquid", "glass", "lg"]
    readonly property var jokes: [
        Translation.tr("Wrong key. Don't waste your time on nonsense."),
        Translation.tr("Nope. Go touch grass instead of guessing keys."),
        Translation.tr("That's not it. Seriously, stop messing around."),
        Translation.tr("Wrong. Is this really how you spend your evening?"),
        Translation.tr("Incorrect. The key is not \"please\" either.")
    ]
    readonly property var rickKeys: ["rickroll", "rick", "never gonna give you up"]
    readonly property string rickUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    property int taps: 0
    property bool secretOpen: false
    property string secretHint: ""

    spacing: 24

    Process {
        running: true
        command: ["sh", "-c", 'git -C "$1" log -1 --format="%h · %cs" 2>/dev/null; qs --version 2>/dev/null | head -1', "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.revision = l[0] ?? "";
                root.quickshell = l[1] ?? "";
            }
        }
    }

    RowLayout {
        spacing: 20
        // The logo is the way to the secret setting, so it hints at itself: it lights up once when
        // the page opens, shrinks under the pointer, gives under a press, and turns a little with
        // every tap (the fifth is a bigger burst, and the setting appears).
        Item {
            id: logo

            property real turn: 0
            property real flash: 0 // 0..1, how much the logo is lit
            property real ripple: 0 // 0..1, progress of the ring leaving it
            property real rippleSize: 1.6

            implicitWidth: 96
            implicitHeight: 96
            scale: tap.pressed ? 0.86 : tap.containsMouse ? 0.92 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.spatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.spatialFast
                }
            }

            function burst(size) {
                rippleSize = size;
                ripple = 0;
                rippleAnim.restart();
            }

            Component.onCompleted: hint.start()

            // Once, a moment after the page opens: two rings and a glow
            SequentialAnimation {
                id: hint
                PauseAnimation { duration: 700 }
                ScriptAction { script: { logo.burst(1.7); logo.turn += 72; } }
                NumberAnimation { target: logo; property: "flash"; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: logo; property: "flash"; to: 0; duration: 900; easing.type: Easing.InOutCubic }
                ScriptAction { script: logo.burst(1.7) }
            }

            NumberAnimation {
                id: rippleAnim
                target: logo
                property: "ripple"
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.OutCubic
            }

            // The ring that leaves the logo
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width * (1 + (logo.rippleSize - 1) * logo.ripple)
                height: width
                shape: "sunny"
                animated: false
                color: "transparent"
                borderColor: Colors.m3primary
                borderWidth: 3
                shapeRotation: logo.turn
                opacity: logo.ripple > 0 && logo.ripple < 1 ? 1 - logo.ripple : 0
            }
            // The glow behind it
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width * 1.25
                height: width
                shape: "sunny"
                animated: false
                color: Colors.m3primary
                shapeRotation: logo.turn
                opacity: 0.35 * logo.flash
            }
            MaterialShape {
                anchors.fill: parent
                shape: "sunny"
                shapeRotation: logo.turn
                color: Qt.tint(Colors.m3primaryContainer, Qt.rgba(Colors.m3primary.r, Colors.m3primary.g, Colors.m3primary.b, 0.55 * logo.flash))
            }
            MouseArea {
                id: tap
                anchors.fill: parent
                z: 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.taps++;
                    tapReset.restart();
                    logo.turn += 72; // five taps make a full turn
                    if (root.taps >= root.secretTaps) {
                        root.taps = 0;
                        root.secretOpen = true;
                        logo.burst(2.4);
                    } else {
                        logo.burst(1.35);
                    }
                }
            }
            Timer {
                id: tapReset
                interval: 1500
                onTriggered: root.taps = 0
            }
            MaterialIcon {
                anchors.centerIn: parent
                icon: "auto_awesome"
                fill: 1
                iconSize: 44
                color: Colors.m3onPrimaryContainer
                rotation: logo.flash * 20
            }
        }
        ColumnLayout {
            spacing: 2
            StyledText {
                text: "hi-shell"
                font.pixelSize: Appearance.font.size.headlineMedium
                font.weight: Font.Medium
            }
            StyledText {
                text: Translation.tr("A Material 3 Expressive desktop shell for Hyprland")
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                text: root.revision ? Translation.tr("Version %1").arg(root.revision) : ""
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3outline
            }
        }
    }

    Section {
        visible: root.secretOpen
        icon: "key"
        title: Translation.tr("Secret setting")

        TextRow {
            icon: "vpn_key"
            title: Translation.tr("Key")
            subtitle: root.secretHint || Translation.tr("Enter the key")
            placeholder: Translation.tr("Key")
            fieldWidth: 180
            onEdited: text => {
                const key = text.trim();
                if (key === "")
                    return;
                if (root.rickKeys.includes(key.toLowerCase())) {
                    // No overlay here: it would sit on top of the browser that opens
                    root.secretHint = Translation.tr("Never gonna give you up");
                    Qt.openUrlExternally(root.rickUrl);
                } else if (root.secretKeys.includes(key.toLowerCase())) {
                    root.secretHint = "";
                    root.secretOpen = false;
                    ShellState.secretEgg = key.toLowerCase();
                } else {
                    root.secretHint = root.jokes[Math.floor(Math.random() * root.jokes.length)];
                }
            }
        }
    }

    Section {
        icon: "system_update"
        title: Translation.tr("Updates")

        ChoiceRow {
            icon: "sync_alt"
            title: Translation.tr("Update from")
            subtitle: Config.options.update.channel === "release" ? Translation.tr("Release: update.sh moves to the latest tagged release") : Translation.tr("Git: update.sh pulls the latest main, the newest features")
            value: Config.options.update.channel
            options: [{ value: "release", text: Translation.tr("Release") }, { value: "git", text: "Git" }]
            onSelected: value => Config.options.update.channel = value
        }
        SwitchRow {
            icon: "notifications_active"
            title: Translation.tr("Window about a new version")
            subtitle: Translation.tr("At startup, when an update is available")
            checked: Config.options.update.notify
            onToggled: checked => Config.options.update.notify = checked
        }
        ListRow {
            Layout.fillWidth: true
            icon: "deployed_code"
            title: Translation.tr("hi-shell")
            subtitle: root.shellStatus
            IconButton {
                icon: "sync"
                tooltip: Translation.tr("Check for updates")
                enabled: !Updates.shellChecking
                onClicked: Updates.checkShell()
            }
            M3Button {
                text: Updates.updating ? Translation.tr("Updating…") : Translation.tr("Update the shell")
                icon: "system_update_alt"
                enabled: !Updates.updating
                onClicked: Updates.updateShell()
            }
        }
        // The output of the update: the shell restarts when it's done
        Rectangle {
            Layout.fillWidth: true
            visible: Updates.updating || Updates.updateLog !== ""
            implicitHeight: Math.min(260, updateText.implicitHeight + 28)
            radius: Appearance.rounding.large
            color: Updates.updateFailed ? Colors.m3errorContainer : Colors.m3surfaceContainer
            clip: true

            Flickable {
                id: updateFlick
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: updateText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                StyledText {
                    id: updateText
                    width: parent.width
                    text: Updates.updateLog || Translation.tr("Updating…")
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.labelMedium
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    color: Updates.updateFailed ? Colors.m3onErrorContainer : Colors.m3onSurface
                }
            }
        }
    }

    Section {
        id: presets
        icon: "inventory_2"
        title: Translation.tr("Presets")

        property string name: ""
        property string importPath: ""

        Component.onCompleted: Presets.refresh()

        TextRow {
            icon: "save"
            title: Translation.tr("Save current setup")
            subtitle: Translation.tr("Config, wallpaper and colors; API keys, location and monitors stay out")
            placeholder: Translation.tr("Name")
            fieldWidth: 180
            onEdited: text => presets.name = text
            M3Button {
                text: Translation.tr("Save")
                enabled: !Presets.busy
                onClicked: Presets.exportPreset(presets.name)
            }
        }
        Repeater {
            model: Presets.list
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: "style"
                title: modelData.name
                subtitle: [modelData.created.replace("T", " ").slice(0, 16), modelData.wallpaper].filter(s => s).join(" · ")
                M3Button {
                    tonal: true
                    text: Translation.tr("Apply")
                    enabled: !Presets.busy
                    onClicked: Presets.importPreset(modelData.path)
                }
                IconButton {
                    icon: "delete"
                    tooltip: Translation.tr("Delete")
                    onClicked: Presets.remove(modelData.path)
                }
            }
        }
        TextRow {
            icon: "upload_file"
            title: Translation.tr("Apply from a file")
            subtitle: Presets.error || Translation.tr("A .tar.gz preset someone shared")
            placeholder: "~/Downloads/preset.tar.gz"
            fieldWidth: 220
            onEdited: text => presets.importPath = text.trim()
            M3Button {
                tonal: true
                text: Translation.tr("Apply")
                enabled: presets.importPath !== "" && !Presets.busy
                onClicked: Presets.importPreset(presets.importPath)
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "folder_open"
            title: Translation.tr("Open presets folder")
            subtitle: Presets.dir.replace(Paths.home, "~")
            clickable: true
            onClicked: {
                Quickshell.execDetached(["mkdir", "-p", Presets.dir]);
                Qt.openUrlExternally(`file://${Presets.dir}`);
            }
        }
    }

    Section {
        icon: "info"
        title: Translation.tr("Components")

        ListRow { Layout.fillWidth: true; icon: "deployed_code"; title: "Quickshell"; subtitle: root.quickshell }
        ListRow { Layout.fillWidth: true; icon: "palette"; title: "matugen"; subtitle: Translation.tr("Material 3 colors from the wallpaper") }
        ListRow { Layout.fillWidth: true; icon: "settings"; title: Translation.tr("Config"); subtitle: Config.path.replace(Paths.home, "~") }
    }

    Section {
        icon: "link"
        title: Translation.tr("Links")

        ListRow {
            Layout.fillWidth: true
            icon: "code"
            title: Translation.tr("Source")
            subtitle: "github.com/imu-useful/hi-shell"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/imu-useful/hi-shell")
        }
        ListRow {
            Layout.fillWidth: true
            icon: "favorite"
            title: Translation.tr("Inspired by end4-pC and illogical-impulse")
            subtitle: "github.com/pctrade/end4-pC · github.com/end-4/dots-hyprland"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/pctrade/end4-pC")
        }
    }
}
