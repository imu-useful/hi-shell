import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services
import qs.modules.settings

// First-run welcome: language, look, the AI (a choice, or off), shortcuts and missing programs.
// Shown once (until ~/.local/state/hi-shell/welcome-done exists);
// reopen with `qs -c hi-shell ipc call welcome open`.
Scope {
    id: root

    property bool open: false
    property int step: 0
    readonly property int steps: 5
    property var missing: []

    // [command, what needs it]
    readonly property var programs: [
        ["matugen", "colors from the wallpaper"], ["claude", "AI chat with Claude"], ["cliphist", "clipboard history"],
        ["trans", "translator"], ["qalc", "calculator"], ["grim", "screenshots"], ["slurp", "screenshots"],
        ["tesseract", "OCR"], ["wf-recorder", "screen recording"], ["cava", "visualizer"],
        ["hyprlock", "lock screen"], ["hyprsunset", "night light"], ["brightnessctl", "brightness"],
        ["magick", "wallpaper thumbnails"]
    ]

    // Without the AI there's no palette to open.
    readonly property var shortcuts: Config.options.ai.enabled ? allShortcuts : allShortcuts.filter(s => s[0] !== "Super + Y")
    readonly property var allShortcuts: [
        ["Super", "App launcher"], ["Super + Y", "AI palette"], ["Super + Z", "Left sidebar"],
        ["Super + U", "Right sidebar"], ["Super + Tab", "Workspace overview"], ["Super + R", "Wallpaper picker"],
        ["Super + Shift + S", "Screenshot / OCR / record"], ["Super + V", "Clipboard history"],
        ["Super + Escape", "Settings"]
    ]

    function finish(): void {
        root.open = false;
        doneFile.setText(new Date().toISOString() + "\n");
    }

    Connections {
        target: ShellState
        function onShowWelcome() {
            root.step = 0;
            root.open = true;
        }
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            root.step = 0;
            root.open = true;
        }
        function close(): void {
            root.finish();
        }
    }

    FileView {
        id: doneFile
        path: `${Paths.state}/welcome-done`
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.open = true;
        }
    }

    Process {
        running: root.open && root.step === root.steps - 1
        command: ["sh", "-c", 'for c in "$@"; do command -v "$c" >/dev/null || echo "$c"; done', "sh", ...root.programs.map(p => p[0])]
        stdout: StdioCollector {
            onStreamFinished: root.missing = text.split("\n").filter(c => c)
        }
    }

    PanelLoader {
        id: loader
        // Step aside while the wallpaper picker is open on top.
        shown: root.open && !ShellState.wallpaperSelectorOpen

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: Qt.alpha("black", loader.revealed ? 0.35 : 0)
            Behavior on color { ColorAnim {} }

            WlrLayershell.namespace: "hi-shell-welcome"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Shortcut {
                sequence: "Escape"
                onActivated: root.finish()
            }
            Shortcut {
                sequences: ["Right", "Return", "Enter"]
                onActivated: root.step === root.steps - 1 ? root.finish() : root.step++
            }
            Shortcut {
                sequence: "Left"
                enabled: root.step > 0
                onActivated: root.step--
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 720)
                height: Math.min(parent.height - 100, 600)
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainerLow
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 20

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: [hello, look, ai, keys, done][root.step]
                    }

                    // --- Navigation ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Row {
                            spacing: 6
                            Repeater {
                                model: root.steps
                                Rectangle {
                                    required property int index
                                    width: index === root.step ? 24 : 8
                                    height: 8
                                    radius: 4
                                    color: index === root.step ? Colors.m3primary : Colors.m3outlineVariant
                                    Behavior on width { SpatialAnim {} }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Button {
                            visible: root.step === 0
                            tonal: true
                            text: Translation.tr("Skip")
                            onClicked: root.finish()
                        }
                        M3Button {
                            visible: root.step > 0
                            tonal: true
                            text: Translation.tr("Back")
                            onClicked: root.step--
                        }
                        M3Button {
                            text: root.step === root.steps - 1 ? Translation.tr("Start") : Translation.tr("Next")
                            icon: root.step === root.steps - 1 ? "check" : "arrow_forward"
                            onClicked: root.step === root.steps - 1 ? root.finish() : root.step++
                        }
                    }
                }
            }

            // --- Steps ---
            Component {
                id: hello
                ColumnLayout {
                    spacing: 16
                    Item { Layout.fillHeight: true }
                    MaterialShape {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 120
                        implicitHeight: 120
                        shape: "cookie9"
                        color: Colors.m3primaryContainer
                        // A waving hand: pops in, then waves from the wrist every few seconds.
                        Text {
                            id: hand
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 2
                            text: "👋"
                            font.pixelSize: 60
                            // Pivot at the wrist (bottom right of the glyph).
                            transformOrigin: Item.BottomRight
                            scale: 0

                            Component.onCompleted: popIn.start()
                            SpringAnim {
                                id: popIn
                                target: hand
                                property: "scale"
                                from: 0
                                to: 1
                                onFinished: wave.start()
                            }
                            SequentialAnimation {
                                id: wave
                                loops: Animation.Infinite
                                NumberAnimation { target: hand; property: "rotation"; to: 14; duration: 150; easing.type: Easing.InOutSine }
                                NumberAnimation { target: hand; property: "rotation"; to: -8; duration: 180; easing.type: Easing.InOutSine }
                                NumberAnimation { target: hand; property: "rotation"; to: 14; duration: 180; easing.type: Easing.InOutSine }
                                NumberAnimation { target: hand; property: "rotation"; to: -4; duration: 180; easing.type: Easing.InOutSine }
                                NumberAnimation { target: hand; property: "rotation"; to: 10; duration: 180; easing.type: Easing.InOutSine }
                                NumberAnimation { target: hand; property: "rotation"; to: 0; duration: 220; easing.type: Easing.OutSine }
                                PauseAnimation { duration: 1500 }
                            }
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Welcome to hi-shell")
                        font.family: Appearance.font.title
                        font.pixelSize: Appearance.font.size.displaySmall
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 480
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Translation.tr("A few quick choices and you're set. Everything here can be changed later in Settings.")
                        color: Colors.m3onSurfaceVariant
                    }
                    Item { implicitHeight: 8 }
                    SegmentedButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: false
                        readonly property var codes: ["auto", ...Translation.available.map(l => l.code)]
                        model: [{ text: Translation.tr("Auto"), icon: "language" }, ...Translation.available.map(l => ({ text: l.name }))]
                        currentIndex: Math.max(0, codes.indexOf(Config.options.language))
                        onSelected: index => Config.options.language = codes[index]
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Component {
                id: look
                ColumnLayout {
                    spacing: 16
                    StyledText {
                        text: Translation.tr("Make it yours")
                        font.family: Appearance.font.title
                        font.pixelSize: Appearance.font.size.headlineSmall
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Rectangle {
                            implicitWidth: 260
                            implicitHeight: 146
                            radius: Appearance.rounding.large
                            color: Colors.m3surfaceContainerHighest
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: Wallpapers.current ? `file://${Wallpapers.current}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 520
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            StyledText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Translation.tr("Colors follow the wallpaper.")
                                color: Colors.m3onSurfaceVariant
                            }
                            M3Button {
                                icon: "wallpaper"
                                text: Translation.tr("Choose wallpaper")
                                onClicked: ShellState.wallpaperSelectorOpen = true
                            }
                            M3Button {
                                tonal: true
                                icon: "shuffle"
                                text: Translation.tr("Random")
                                onClicked: Wallpapers.local.length ? Wallpapers.random() : Wallpapers.scan()
                            }
                        }
                    }
                    ListRow {
                        Layout.fillWidth: true
                        icon: "contrast"
                        title: Translation.tr("Mode")
                        SegmentedButton {
                            readonly property var values: ["light", "dark", "auto"]
                            model: [{ text: Translation.tr("Light"), icon: "light_mode" }, { text: Translation.tr("Dark"), icon: "dark_mode" }, { text: Translation.tr("Auto"), icon: "brightness_auto" }]
                            currentIndex: values.indexOf(Config.options.appearance.autoMode ? "auto" : Colors.mode)
                            onSelected: index => {
                                Config.options.appearance.autoMode = values[index] === "auto";
                                if (values[index] !== "auto")
                                    Theme.setMode(values[index]);
                            }
                        }
                    }
                    ListRow {
                        Layout.fillWidth: true
                        icon: "toolbar"
                        title: Translation.tr("Bar style")
                        SegmentedButton {
                            readonly property var values: ["hug", "float", "islands", "m3"]
                            model: [Translation.tr("Hug"), Translation.tr("Float"), Translation.tr("Islands"), "M3"]
                            currentIndex: Math.max(0, values.indexOf(Config.options.bar.style))
                            onSelected: index => Config.options.bar.style = values[index]
                        }
                    }
                    ListRow {
                        Layout.fillWidth: true
                        icon: "vertical_align_top"
                        title: Translation.tr("Bar position")
                        SegmentedButton {
                            readonly property var values: ["top", "bottom", "left", "right"]
                            model: [Translation.tr("Top"), Translation.tr("Bottom"), Translation.tr("Left"), Translation.tr("Right")]
                            currentIndex: Math.max(0, values.indexOf(Config.options.bar.position))
                            onSelected: index => Config.options.bar.position = values[index]
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Component {
                id: ai
                ColumnLayout {
                    spacing: 12
                    StyledText {
                        text: Translation.tr("AI")
                        font.family: Appearance.font.title
                        font.pixelSize: Appearance.font.size.headlineSmall
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: Translation.tr("An AI chat in the left sidebar and a palette on Super + Y. Pick who answers, or turn it off.")
                        color: Colors.m3onSurfaceVariant
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Chip {
                            icon: "block"
                            text: Translation.tr("Off")
                            selected: !Config.options.ai.enabled
                            onClicked: Config.options.ai.enabled = false
                        }
                        Chip {
                            icon: "auto_awesome"
                            text: "Claude"
                            selected: Config.options.ai.enabled && Claude.provider === "claude"
                            onClicked: {
                                Config.options.ai.enabled = true;
                                Claude.provider = "claude";
                            }
                        }
                        Repeater {
                            model: Claude.providers
                            Chip {
                                required property var modelData
                                icon: modelData.icon
                                text: modelData.name
                                selected: Config.options.ai.enabled && Claude.provider === modelData.id
                                onClicked: {
                                    Config.options.ai.enabled = true;
                                    Claude.provider = modelData.id;
                                }
                            }
                        }
                    }

                    // What the choice needs.
                    StyledText {
                        Layout.fillWidth: true
                        visible: !Config.options.ai.enabled
                        wrapMode: Text.Wrap
                        text: Translation.tr("The AI tab and the palette stay hidden. Settings > General turns it on again.")
                        color: Colors.m3onSurfaceVariant
                    }
                    ListRow {
                        Layout.fillWidth: true
                        visible: Config.options.ai.enabled && Claude.provider === "claude"
                        icon: "terminal"
                        title: Translation.tr("Claude needs Claude Code")
                        subtitle: Translation.tr("npm install -g @anthropic-ai/claude-code, then run claude once to sign in")
                    }
                    TextRow {
                        visible: Config.options.ai.enabled && Claude.compat && (Claude.spec?.key ?? false)
                        icon: "key"
                        title: Translation.tr("%1 API key").arg(Claude.providerName)
                        subtitle: Claude.spec?.keyUrl ? Translation.tr("Get one at %1; the model is picked in the sidebar chat").arg(Claude.spec.keyUrl) : ""
                        value: Claude.keyFor(Claude.provider)
                        secret: true
                        fieldWidth: 240
                        onEdited: text => Claude.setKey(Claude.provider, text.trim())
                    }
                    TextRow {
                        visible: Config.options.ai.enabled && Claude.compat && (Claude.provider === "ollama" || (Claude.spec?.urlRequired ?? false))
                        icon: "link"
                        title: Translation.tr("%1 server address").arg(Claude.providerName)
                        subtitle: Claude.spec?.urlRequired ? Translation.tr("Ending in /v1, e.g. http://localhost:1234/v1") : Translation.tr("Default %1").arg(Claude.spec?.url ?? "")
                        value: Config.options.ai.urls[Claude.provider] ?? ""
                        placeholder: Claude.spec?.url ?? ""
                        fieldWidth: 240
                        onEdited: text => Claude.setUrl(Claude.provider, text.trim())
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: Config.options.ai.enabled
                        wrapMode: Text.Wrap
                        text: Translation.tr("Models and the rest are in Settings > General.")
                        color: Colors.m3outline
                        font.pixelSize: Appearance.font.size.labelMedium
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Component {
                id: keys
                ColumnLayout {
                    spacing: 12
                    StyledText {
                        text: Translation.tr("Shortcuts")
                        font.family: Appearance.font.title
                        font.pixelSize: Appearance.font.size.headlineSmall
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: Translation.tr("Type < in the launcher to search all of them.")
                        color: Colors.m3onSurfaceVariant
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Repeater {
                            model: root.shortcuts
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 10
                                Rectangle {
                                    implicitWidth: keyText.implicitWidth + 16
                                    implicitHeight: 28
                                    radius: Appearance.rounding.small
                                    color: Colors.m3secondaryContainer
                                    StyledText {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: modelData[0]
                                        font.family: Appearance.font.mono
                                        font.pixelSize: Appearance.font.size.labelMedium
                                        color: Colors.m3onSecondaryContainer
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: Translation.tr(modelData[1])
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Component {
                id: done
                ColumnLayout {
                    spacing: 12
                    StyledText {
                        text: Translation.tr("All set")
                        font.family: Appearance.font.title
                        font.pixelSize: Appearance.font.size.headlineSmall
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.missing.length
                            ? Translation.tr("These programs are missing, so the features using them won't work until you install them:")
                            : Translation.tr("Every optional program hi-shell uses is installed.")
                        color: Colors.m3onSurfaceVariant
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            // The claude CLI only matters when Claude is the one answering.
                            model: root.missing.filter(c => c !== "claude" || (Config.options.ai.enabled && Config.options.ai.provider === "claude"))
                            Chip {
                                required property string modelData
                                icon: "error"
                                text: `${modelData} · ${Translation.tr(root.programs.find(p => p[0] === modelData)?.[1] ?? "")}`
                            }
                        }
                    }
                    ListRow {
                        Layout.fillWidth: true
                        visible: root.missing.includes("claude") && Config.options.ai.enabled && Config.options.ai.provider === "claude"
                        icon: "auto_awesome"
                        title: Translation.tr("Claude needs Claude Code")
                        subtitle: Translation.tr("npm install -g @anthropic-ai/claude-code, then run claude once to sign in")
                    }
                    ListRow {
                        Layout.fillWidth: true
                        icon: "settings"
                        title: Translation.tr("Settings")
                        subtitle: Translation.tr("Super + Escape, or type / in the launcher")
                    }
                    ListRow {
                        Layout.fillWidth: true
                        icon: "inventory_2"
                        title: Translation.tr("Presets")
                        subtitle: Translation.tr("Settings › About saves your setup to a file you can restore or share")
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
