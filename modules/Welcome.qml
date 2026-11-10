import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services
import qs.modules.settings
import qs.modules.secret

// First-run welcome: first the keynote (modules/secret/Keynote.qml) full screen, watched to the end
// on the first run, until its "Get started" button; then the setup: language, look, the AI (a
// choice, or off), shortcuts and missing programs. Shown once (until
// ~/.local/state/hi-shell/welcome-done exists); reopen with `qs -c hi-shell ipc call welcome open`
// (then Escape skips the show).
Scope {
    id: root

    property bool open: false
    // The keynote plays before the setup; `keynoteLoaded` lingers while it fades out
    property bool keynote: false
    property bool keynoteLoaded: false
    property bool keynoteSkippable: true
    property int step: 0
    readonly property int steps: 5
    property var missing: []
    // The step on screen: it lags `step` while the old one slides out
    property int shownStep: 0
    property int direction: 1
    property bool leaving: false
    // Runs 0 -> 10 each time a step comes in; rise(i) is how far its i-th piece has risen into place
    property real reveal: 10

    function rise(i: real): real {
        const p = Math.max(0, Math.min(1, reveal - i * 0.7));
        return 1 - Math.pow(1 - p, 3);
    }

    // A step's title with its icon in a cookie, and a line under it
    component StepHeader: RowLayout {
        id: header
        property string icon
        property string title
        property string subtitle
        Layout.fillWidth: true
        spacing: 16
        opacity: root.rise(0)
        transform: Translate { y: (1 - root.rise(0)) * 18 }

        MaterialShape {
            implicitWidth: 52
            implicitHeight: 52
            shape: "cookie9"
            color: Colors.m3primaryContainer
            rotation: (1 - root.rise(0)) * -90
            MaterialIcon {
                anchors.centerIn: parent
                icon: header.icon
                iconSize: 26
                fill: 1
                color: Colors.m3onPrimaryContainer
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: header.title
                font.family: Appearance.font.title
                font.pixelSize: Appearance.font.size.headlineSmall
            }
            StyledText {
                Layout.fillWidth: true
                visible: header.subtitle !== ""
                wrapMode: Text.Wrap
                text: header.subtitle
                color: Colors.m3onSurfaceVariant
            }
        }
    }

    // Rises into place as the `index`-th piece of the step
    component Rise: Translate {
        property real index
        y: (1 - root.rise(index)) * 18
    }

    // A soft round light in `tint`, fading out from its middle
    component Glow: Shape {
        id: glow
        property color tint
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.width / 2
                centerY: glow.height / 2
                centerRadius: glow.width / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: glow.tint }
                GradientStop { position: 0.45; color: Qt.alpha(glow.tint, glow.tint.a * 0.4) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc {
                centerX: glow.width / 2
                centerY: glow.height / 2
                radiusX: glow.width / 2
                radiusY: glow.height / 2
                sweepAngle: 360
            }
        }
    }

    onStepChanged: {
        if (step === shownStep)
            return;
        direction = step > shownStep ? 1 : -1;
        swap.restart();
    }

    SequentialAnimation {
        id: swap
        ScriptAction { script: root.leaving = true }
        NumberAnimation { target: root; property: "reveal"; to: 0; duration: 140; easing.type: Easing.InCubic }
        ScriptAction { script: { root.leaving = false; root.shownStep = root.step; } }
        NumberAnimation { target: root; property: "reveal"; from: 0; to: 10; duration: 1100 }
    }

    function intro(): void {
        swap.stop();
        shownStep = step;
        reveal = 0;
        introAnim.restart();
    }
    NumberAnimation { id: introAnim; target: root; property: "reveal"; from: 0; to: 10; duration: 1400 }

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

    function startKeynote(skippable: bool): void {
        keynoteSkippable = skippable;
        keynote = true;
        keynoteLoaded = true;
        open = true;
    }

    // The show is over (or skipped): on to the setup
    function endKeynote(): void {
        keynote = false;
        unloadKeynote.restart();
        step = 0;
        intro();
    }

    Timer {
        id: unloadKeynote
        interval: 700
        onTriggered: root.keynoteLoaded = false
    }

    function finish(): void {
        root.open = false;
        doneFile.setText(new Date().toISOString() + "\n");
    }

    Connections {
        target: ShellState
        function onShowWelcome() {
            root.step = 0;
            root.startKeynote(true);
        }
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            root.step = 0;
            root.startKeynote(true);
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
                root.startKeynote(false);
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
            color: Qt.alpha("black", !loader.revealed ? 0 : root.keynote ? 1 : 0.45)
            Behavior on color { ColorAnim {} }

            WlrLayershell.namespace: "hi-shell-welcome"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Shortcut {
                sequence: "Escape"
                enabled: !root.keynote || root.keynoteSkippable
                onActivated: root.keynote ? root.endKeynote() : root.finish()
            }
            Shortcut {
                sequences: ["Right", "Return", "Enter"]
                enabled: !root.keynote
                onActivated: root.step === root.steps - 1 ? root.finish() : root.step++
            }
            Shortcut {
                sequence: "Left"
                enabled: root.step > 0 && !root.keynote
                onActivated: root.step--
            }

            Loader {
                anchors.fill: parent
                active: root.keynoteLoaded
                opacity: root.keynote ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                sourceComponent: Keynote {
                    revealed: loader.revealed && root.keynote
                    skippable: false
                    actionText: Translation.tr("Get started")
                    onAction: root.endKeynote()
                }
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 720)
                height: Math.min(parent.height - 100, 640)
                radius: Appearance.shape.panel
                color: Colors.m3surfaceContainerLow
                border.width: Appearance.edge
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                enabled: !root.keynote
                opacity: loader.revealed && !root.keynote ? 1 : 0
                scale: loader.revealed && !root.keynote ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                // Light in the wallpaper's colors drifting behind the steps (brighter on the hello),
                // cut to the card's rounded shape
                Item {
                    id: ambient
                    anchors.fill: parent
                    opacity: root.shownStep === 0 ? 1 : 0.55
                    Behavior on opacity { EffectAnim { duration: 600 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: cardMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    property real phase: 0
                    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 24000; loops: Animation.Infinite }

                    Glow {
                        width: card.width * 0.95
                        height: width
                        x: card.width * 0.55 - width / 2 + Math.cos(ambient.phase) * 60
                        y: -height * 0.32 + Math.sin(ambient.phase * 2) * 30
                        tint: Qt.alpha(Colors.m3primary, 0.24)
                    }
                    Glow {
                        width: card.width * 0.8
                        height: width
                        x: -width * 0.3 + Math.sin(ambient.phase) * 50
                        y: card.height - height * 0.55 + Math.cos(ambient.phase) * 30
                        tint: Qt.alpha(Colors.m3tertiary, 0.18)
                    }
                }
                Rectangle {
                    id: cardMask
                    anchors.fill: parent
                    radius: card.radius
                    visible: false
                    layer.enabled: true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 20

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: [hello, look, ai, keys, done][root.shownStep]
                        // Slides in from the side it's going to, a little
                        opacity: Math.min(1, root.reveal)
                        transform: Translate { x: (1 - root.rise(0)) * 36 * (root.leaving ? -root.direction : root.direction) }
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
                                    color: index === root.step ? Colors.m3primary : dotHover.hovered ? Colors.m3outline : Colors.m3outlineVariant
                                    Behavior on width { SpatialAnim {} }
                                    Behavior on color { ColorAnim {} }
                                    HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        margin: 6
                                        onTapped: root.step = parent.index
                                    }
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
                    spacing: 14
                    Item { Layout.fillHeight: true }
                    // The emblem: the hand on a slowly turning cookie, a paler sun turning the other way behind
                    Item {
                        id: emblem
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 140
                        implicitHeight: 140
                        opacity: root.rise(0)
                        scale: 0.7 + 0.3 * root.rise(0)

                        property real spin: 0
                        NumberAnimation on spin { from: 0; to: 360; duration: 40000; loops: Animation.Infinite }

                        MaterialShape {
                            anchors.centerIn: parent
                            width: 140
                            height: 140
                            shape: "sunny"
                            color: Qt.alpha(Colors.m3primary, 0.16)
                            rotation: -emblem.spin * 0.6
                        }
                        MaterialShape {
                            anchors.centerIn: parent
                            width: 108
                            height: 108
                            shape: "cookie9"
                            color: Colors.m3primaryContainer
                            rotation: emblem.spin
                        }
                        // Pops in, then waves (the arcs pulsing) every few seconds
                        HandLogo {
                            id: hand
                            anchors.centerIn: parent
                            size: 60
                            color: Colors.m3onPrimaryContainer
                            arcColor: Colors.m3tertiary
                            scale: 0

                            Component.onCompleted: popIn.start()
                            SequentialAnimation {
                                id: popIn
                                PauseAnimation { duration: 150 }
                                SpringAnim { target: hand; property: "scale"; from: 0; to: 1; overshoot: 2.4 }
                                ScriptAction { script: waveTimer.start() }
                            }
                            Timer {
                                id: waveTimer
                                interval: 2800
                                repeat: true
                                triggeredOnStart: true
                                onTriggered: hand.wave()
                            }
                        }
                    }
                    // One line, so "hi-shell" (in the accent color) sits on the same baseline
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        opacity: root.rise(1)
                        transform: Rise { index: 1 }
                        textFormat: Text.StyledText
                        text: `${Translation.tr("Welcome to")} <font color="${Colors.m3primary}"><b>hi-shell</b></font>`
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
                        opacity: root.rise(2)
                        transform: Rise { index: 2 }
                    }
                    Item { implicitHeight: 8 }
                    SegmentedButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: false
                        opacity: root.rise(3)
                        transform: Rise { index: 3 }
                        readonly property var codes: ["auto", ...Translation.available.map(l => l.code)]
                        model: [{ text: Translation.tr("Auto"), icon: "language" }, ...Translation.available.map(l => ({ text: l.name }))]
                        currentIndex: Math.max(0, codes.indexOf(Config.options.language))
                        onSelected: index => Config.options.language = codes[index]
                    }
                    Item { implicitHeight: 4 }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("News in the channel, questions and chat in the group")
                        color: Colors.m3outline
                        opacity: root.rise(4)
                        transform: Rise { index: 4 }
                        font.pixelSize: Appearance.font.size.labelMedium
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        opacity: root.rise(4)
                        transform: Rise { index: 4 }
                        M3Button {
                            tonal: true
                            icon: "campaign"
                            text: Translation.tr("Channel")
                            onClicked: Qt.openUrlExternally("https://t.me/hi_shell")
                        }
                        M3Button {
                            tonal: true
                            icon: "forum"
                            text: Translation.tr("Group")
                            onClicked: Qt.openUrlExternally("https://t.me/tux_emp")
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Component {
                id: look
                ColumnLayout {
                    spacing: 16
                    StepHeader {
                        icon: "palette"
                        title: Translation.tr("Make it yours")
                        subtitle: Translation.tr("Colors follow the wallpaper.")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        opacity: root.rise(1)
                        transform: Rise { index: 1 }
                        Rectangle {
                            implicitWidth: 260
                            implicitHeight: 146
                            radius: Appearance.rounding.large
                            color: Colors.m3surfaceContainerHighest
                            // Cut to the rounded corners
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: previewMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }
                            Rectangle {
                                id: previewMask
                                anchors.fill: parent
                                radius: parent.radius
                                visible: false
                                layer.enabled: true
                            }
                            Image {
                                anchors.fill: parent
                                source: Wallpapers.still ? `file://${Wallpapers.still}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 520
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
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
                        opacity: root.rise(2)
                        transform: Rise { index: 2 }
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
                        opacity: root.rise(3)
                        transform: Rise { index: 3 }
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
                        opacity: root.rise(4)
                        transform: Rise { index: 4 }
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
                    StepHeader {
                        icon: "auto_awesome"
                        title: Translation.tr("AI")
                        subtitle: Translation.tr("An AI chat in the left sidebar and a palette on Super + Y. Pick who answers, or turn it off.")
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        opacity: root.rise(1)
                        transform: Rise { index: 1 }

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
                    StepHeader {
                        icon: "keyboard"
                        title: Translation.tr("Shortcuts")
                        subtitle: Translation.tr("Type < in the launcher to search all of them.")
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Repeater {
                            model: root.shortcuts
                            RowLayout {
                                id: shortcutRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                opacity: root.rise(1 + index * 0.5)
                                transform: Rise { index: 1 + shortcutRow.index * 0.5 }
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
                    StepHeader {
                        icon: "celebration"
                        title: Translation.tr("All set")
                        subtitle: root.missing.length
                            ? Translation.tr("These programs are missing, so the features using them won't work until you install them:")
                            : Translation.tr("Every optional program hi-shell uses is installed.")
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
