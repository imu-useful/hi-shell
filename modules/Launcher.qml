import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.launcher
import "settings/Pages.js" as Pages
import "launcher/Expression.js" as Expression

// Spotlight-style launcher. Plain text searches apps (and settings pages);
// a calculation typed as it is ("12*(3+4)") is answered above the apps, no prefix needed;
// prefixes switch the source:  = calculator · > run a command · < keybinds ·
// : emoji · ; clipboard · / settings.
// Toggle: Hyprland keybind (hypr/hi-shell.lua) or `qs -c hi-shell ipc call launcher toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.launcherOpen
    property string query: ""

    readonly property var prefixes: [
        { key: "=", icon: "calculate", name: Translation.tr("Calculator") },
        { key: ">", icon: "terminal", name: Translation.tr("Run command") },
        { key: "<", icon: "keyboard", name: Translation.tr("Keybinds") },
        { key: ":", icon: "mood", name: Translation.tr("Emoji") },
        { key: ";", icon: "content_paste", name: Translation.tr("Clipboard") },
        { key: "/", icon: "settings", name: Translation.tr("Settings") }
    ]
    readonly property string mode: prefixes.some(p => p.key === query[0]) ? query[0] : ""
    readonly property string term: mode ? query.slice(1).trim() : query.trim()

    property string calcResult: ""
    // Plain text that reads as a calculation, and its answer (for that very text).
    readonly property bool mathLike: mode === "" && Expression.isMath(term)
    property string inlineFor: ""
    property string inlineResult: ""
    property var binds: []
    property var emoji: []

    // Items are DesktopEntry apps or plain objects { name, comment, materialIcon | glyph, run() }.
    readonly property var results: {
        switch (mode) {
        case "=":
            return term === "" ? [] : [{
                name: calcResult || "…",
                comment: calcResult ? Translation.tr("Enter copies the result") : term,
                materialIcon: "calculate",
                run: () => Quickshell.clipboardText = calcResult.replace(/^[≈=]\s*/, "")
            }];
        case ">":
            return term === "" ? [] : [
                { name: term, comment: Translation.tr("Run"), materialIcon: "terminal", run: () => Quickshell.execDetached(["sh", "-c", term]) },
                { name: term, comment: Translation.tr("Run in a terminal"), materialIcon: "keyboard_command_key",
                  run: () => Quickshell.execDetached([Config.options.apps.terminal, "-e", "sh", "-c", `${term}; exec $SHELL`]) }
            ];
        case "<":
            return binds.filter(b => (b.label + " " + b.keys).toLowerCase().includes(term.toLowerCase())).slice(0, 60)
                .map(b => ({ name: b.label, comment: b.keys, materialIcon: "keyboard", run: () => {} }));
        case ":":
            return term === "" ? [] : emoji.filter(e => e[1].includes(term.toLowerCase())).slice(0, 40)
                .map(e => ({ name: e[1], comment: Translation.tr("Enter copies it"), glyph: e[0], run: () => Quickshell.clipboardText = e[0] }));
        case ";":
            return Clipboard.entries.filter(e => !e.image && e.text.toLowerCase().includes(term.toLowerCase())).slice(0, 40)
                .map(e => ({ name: e.text.replace(/\s+/g, " "), comment: Translation.tr("Copy"), materialIcon: "content_paste", run: () => Clipboard.copy(e) }));
        case "/":
            return (term ? Pages.search(term, Translation.tr) : Pages.pages).map(settingsItem);
        default:
            return [...inlineMath(), ...focusMatches(term), ...settingsMatches(term), ...filterApps(term)];
        }
    }

    function inlineMath() {
        if (!mathLike || inlineFor !== term || inlineResult === "")
            return [];
        return [{
            name: `${term} = ${inlineResult}`,
            comment: Translation.tr("Enter copies the result"),
            materialIcon: "calculate",
            run: () => Quickshell.clipboardText = inlineResult
        }];
    }

    function settingsItem(p) {
        return {
            name: `${Translation.tr("Settings")} › ${Translation.tr(p.title)}`,
            comment: Translation.tr(p.keywords).split(" ").slice(0, 8).join(", ") + "…",
            materialIcon: p.icon,
            run: () => {
                ShellState.settingsPage = p.id;
                ShellState.settingsOpen = true;
            }
        };
    }

    function settingsMatches(text) {
        return text.length < 2 ? [] : Pages.search(text, Translation.tr).slice(0, 3).map(settingsItem);
    }

    // Focus Mode settings (its own window, not a Settings page).
    function focusMatches(text) {
        const q = text.toLowerCase();
        const words = `focus pomodoro ${Translation.tr("Focus Mode")} ${Translation.tr("Pomodoro")}`.toLowerCase().split(" ");
        if (q.length < 2 || Focus.active || !words.some(w => w.startsWith(q)))
            return [];
        return [{
            name: Translation.tr("Start: %1").arg(Focus.profileName(Focus.profile)),
            comment: Translation.tr("Focus Mode session with this profile"),
            materialIcon: "play_arrow",
            run: () => Focus.start()
        }, {
            name: Translation.tr("Focus Mode"),
            comment: Translation.tr("Pomodoro, profiles, blocked apps and sites"),
            materialIcon: "center_focus_strong",
            run: () => Focus.settingsOpen = true
        }];
    }

    function toggle() {
        ShellState.launcherOpen = !open;
    }

    function close() {
        ShellState.launcherOpen = false;
    }

    // Lower score = better match; -1 = no match.
    function scoreApp(app, q) {
        const name = app.name.toLowerCase();
        if (name.startsWith(q))
            return 0;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 1;
        if (name.includes(q))
            return 2;
        const extra = [app.genericName, app.comment, app.id, ...app.keywords, ...app.categories].join(" ").toLowerCase();
        if (extra.includes(q))
            return 3;
        return -1;
    }

    function filterApps(text) {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const q = text.toLowerCase();
        if (q === "")
            return apps.sort((a, b) => a.name.localeCompare(b.name));
        return apps.map(a => ({ app: a, score: scoreApp(a, q) }))
            .filter(r => r.score >= 0)
            .sort((a, b) => a.score - b.score || a.app.name.localeCompare(b.app.name))
            .map(r => r.app);
    }

    function launch(item) {
        if (!item)
            return;
        if (item.run) {
            item.run();
        } else if (FocusBlocker.blockedEntry(item)) {
            // Focus Mode: not now (the blocker says so).
            FocusBlocker.launch(item);
        } else if (item.runInTerminal) {
            Quickshell.execDetached([Config.options.apps.terminal, "-e", ...item.command]);
        } else {
            item.execute();
        }
        close();
    }

    // Calculator: qalc, debounced.
    onTermChanged: if (mode === "=" || (mode === "" && Expression.isMath(term))) calcTimer.restart()
    Timer {
        id: calcTimer
        interval: 150
        onTriggered: {
            calc.running = false;
            calc.asked = root.term;
            calc.inline = root.mode === "";
            calc.command = ["qalc", "-t", "--", root.term];
            calc.running = true;
        }
    }
    Process {
        id: calc
        // What was asked, and whether it's the plain-text kind (answer shown over the apps).
        property string asked: ""
        property bool inline: false
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = text.trim();
                if (calc.inline) {
                    // qalc leaves 1/0 as it is; that isn't an answer.
                    root.inlineResult = /\/\s*0$/.test(answer) ? "" : answer;
                    root.inlineFor = calc.asked;
                } else {
                    root.calcResult = answer;
                }
            }
        }
        onExited: code => {
            if (code === 127)
                root.calcResult = "qalc (libqalculate) is not installed";
        }
    }

    // Keybinds: loaded each time "<" is typed (they change with the config).
    onModeChanged: {
        if (mode === "<")
            bindLoader.running = true;
        else if (mode === ":" && emoji.length === 0)
            emojiFile.reload();
        else if (mode === ";")
            Clipboard.refresh();
        calcResult = "";
    }
    readonly property var modNames: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    Process {
        id: bindLoader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text).filter(b => !b.submap).map(b => {
                        const mods = root.modNames.filter(([bit]) => b.modmask & bit).map(([, n]) => n);
                        return {
                            label: b.description || `${b.dispatcher} ${b.arg}`.trim(),
                            keys: [...mods, b.key].join(" + ")
                        };
                    });
                } catch (e) {}
            }
        }
    }

    // Emoji list, generated once by services/emoji.py.
    FileView {
        id: emojiFile
        path: Paths.cache + "/emoji.json"
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.emoji = JSON.parse(text());
            } catch (e) {}
        }
        onLoadFailed: emojiMaker.running = true
    }
    Process {
        id: emojiMaker
        command: ["python3", Quickshell.shellDir + "/services/emoji.py", Paths.cache + "/emoji.json"]
        onExited: code => {
            if (code === 0)
                emojiFile.reload();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            ShellState.launcherOpen = true;
        }
        function close(): void {
            root.close();
        }
        // Open with text already typed, e.g. "<" for keybinds or "=" for the calculator.
        function search(text: string): void {
            // The text first: with animations off the window is made (and reads it) at once.
            ShellState.launcherQuery = text;
            ShellState.launcherOpen = true;
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            // Open on the monitor that currently has focus.
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            anchors.top: true
            margins.top: screen ? screen.height * 0.18 : 0
            implicitWidth: 600
            implicitHeight: card.implicitHeight
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "hi-shell-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Clicking anywhere outside the launcher closes it.
            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.close()
            }

            function reset() {
                search.text = ShellState.launcherQuery;
                ShellState.launcherQuery = "";
                root.query = search.text;
                list.currentIndex = 0;
                search.cursorPosition = search.length;
                search.forceActiveFocus();
            }

            // The window is created already open, so also reset on creation.
            Component.onCompleted: reset()
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open)
                        window.reset();
                }
            }

            Rectangle {
                id: card

                width: parent.width
                implicitHeight: column.implicitHeight + 24
                radius: Appearance.rounding.extraLarge
                // Translucent so the compositor blur (see hypr/hi-shell.lua) shows through.
                color: Appearance.translucent(Colors.m3surfaceContainer)
                border.width: 1
                border.color: Colors.m3outlineVariant

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                transformOrigin: Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Search field (M3 search bar)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Appearance.rounding.full
                        color: Colors.m3surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 12

                            MaterialIcon {
                                icon: root.prefixes.find(p => p.key === root.mode)?.icon ?? "search"
                                iconSize: 24
                                color: root.mode ? Colors.m3primary : Colors.m3onSurfaceVariant
                            }

                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                font.family: Appearance.font.main
                                font.pixelSize: 16
                                color: Colors.m3onSurface
                                selectionColor: Colors.m3primary
                                selectedTextColor: Colors.m3onPrimary
                                clip: true

                                onTextChanged: {
                                    root.query = text;
                                    list.currentIndex = 0;
                                }

                                Keys.onEscapePressed: root.close()
                                Keys.onReturnPressed: root.launch(root.results[list.currentIndex])
                                Keys.onEnterPressed: root.launch(root.results[list.currentIndex])
                                Keys.onUpPressed: list.decrementCurrentIndex()
                                Keys.onDownPressed: list.incrementCurrentIndex()
                                Keys.onTabPressed: list.incrementCurrentIndex()
                                Keys.onBacktabPressed: list.decrementCurrentIndex()

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text === ""
                                    text: Translation.tr("Search apps, or type = > < : ; /")
                                    font: search.font
                                    color: Colors.m3onSurfaceVariant
                                }
                            }
                        }
                    }

                    // Prefix hints while the field is empty
                    Flow {
                        Layout.fillWidth: true
                        visible: search.text === ""
                        spacing: 6

                        Repeater {
                            model: root.prefixes
                            Chip {
                                required property var modelData
                                icon: modelData.icon
                                text: `${modelData.key}  ${modelData.name}`
                                onClicked: {
                                    search.text = modelData.key;
                                    search.forceActiveFocus();
                                }
                            }
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        implicitHeight: Math.min(count, 8) * 52 + Math.max(0, Math.min(count, 8) - 1) * spacing
                        visible: count > 0
                        clip: true
                        spacing: 2
                        model: root.results
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: AppItem {
                            width: list.width
                            selected: ListView.isCurrentItem
                            onHovered: list.currentIndex = index
                            onActivated: root.launch(modelData)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        visible: list.count === 0 && search.text !== ""
                        text: root.mode === "" ? Translation.tr("No apps match “%1”").arg(root.query) : root.mode === ":" && root.emoji.length === 0 ? Translation.tr("Loading emoji…") : root.term === "" ? Translation.tr("Type to search") : Translation.tr("Nothing found")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        color: Colors.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
