import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// A font family, installed (item.files) or in the store (item.preview): a sample in the font itself,
// its category and styles, and Install / Use for the interface, titles or monospace / Remove.
Rectangle {
    id: root

    // An entry of Stores.fonts.themes or Stores.fonts.results.
    required property var item
    readonly property var store: Stores.fonts
    readonly property bool local: item.regular !== undefined
    // The same family installed (for a store entry).
    readonly property var have: local ? item : store.themes.find(t => t.id === item.id) ?? null
    readonly property bool busy: store.installing === item.id
    readonly property var f: Config.options.appearance.fonts
    readonly property var uses: [
        { key: "main", text: Translation.tr("Interface") },
        { key: "title", text: Translation.tr("Titles") },
        { key: "mono", text: Translation.tr("Monospace") }
    ]

    // A new family is only known to the shell after a restart (Qt reads the font list at start).
    function use(key) {
        f[key] = item.name;
        if (!Qt.fontFamilies().includes(item.name))
            Stores.restartShell();
    }

    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.large
    color: Colors.m3surfaceContainerHigh

    FontLoader {
        id: loader
        source: root.have?.regular ? "file://" + root.have.regular : root.item.preview ?? ""
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: root.item.name
            elide: Text.ElideRight
            font.family: loader.status === FontLoader.Ready ? loader.name : Appearance.font.main
            font.pixelSize: Appearance.font.size.titleLarge
        }
        StyledText {
            Layout.fillWidth: true
            text: "The quick brown fox jumps over the lazy dog 0123"
            elide: Text.ElideRight
            font.family: loader.status === FontLoader.Ready ? loader.name : Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            color: Colors.m3onSurfaceVariant
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: [Translation.tr(root.item.category ?? ""), root.item.styles ? Translation.tr("%1 styles").arg(root.item.styles) : "",
                       (root.item.scripts ?? []).includes("cyrillic") ? Translation.tr("Cyrillic") : ""].filter(s => s).join(" · ")
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
            IconButton {
                visible: (root.item.page ?? "") !== ""
                implicitWidth: 28
                implicitHeight: 28
                icon: "open_in_new"
                tooltip: Translation.tr("Open in the store")
                onClicked: Qt.openUrlExternally(root.item.page)
            }
            IconButton {
                visible: root.have !== null && !root.busy
                implicitWidth: 28
                implicitHeight: 28
                icon: "delete"
                tooltip: Translation.tr("Remove")
                onClicked: root.store.remove(root.have.id)
            }
        }

        Rectangle {
            visible: root.busy
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Colors.m3surfaceContainerHighest
            Rectangle {
                width: parent.width * Math.max(0.04, root.store.fraction)
                height: parent.height
                radius: 2
                color: Colors.m3primary
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            M3Button {
                visible: root.have === null
                enabled: root.store.installing === ""
                icon: "download"
                text: Translation.tr("Install")
                onClicked: root.store.install(root.item)
            }
            Repeater {
                model: root.have !== null ? root.uses : []
                Chip {
                    required property var modelData
                    readonly property bool inUse: root.f[modelData.key] === root.item.name
                    selected: inUse
                    icon: inUse ? "check" : "text_fields"
                    text: modelData.text
                    onClicked: if (!inUse) root.use(modelData.key)
                }
            }
        }
    }
}
