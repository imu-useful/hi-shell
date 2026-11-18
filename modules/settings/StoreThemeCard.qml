import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// An icon or cursor theme in the KDE Store: its picture, name, author, downloads and rating; Install
// (a theme shipped in several variants asks which one), the download's progress, then Apply.
Rectangle {
    id: root

    // Stores.icons or Stores.cursors
    required property var store
    required property var item
    readonly property var files: item.files ?? []
    readonly property var have: root.store.installedFrom(item.id, root.files.map(f => variant(f)).concat([item.name]))
    readonly property bool busy: root.store.installing === item.id
    property bool picking: false

    function count(n) {
        return n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : String(n);
    }
    // "Tela-black.tar.xz" -> "Tela-black"
    function variant(file) {
        return file.name.replace(/\.(tar\.(gz|xz|bz2|zst)|tgz|txz|tbz2|tar|zip)$/i, "");
    }

    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.large
    color: Colors.m3surfaceContainerHigh

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.56
            radius: Appearance.rounding.medium
            color: Colors.m3surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: root.item.preview
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: root.item.name
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: `${root.item.author} · ${root.count(root.item.downloads)} ↓ · ${root.item.score}%`
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            IconButton {
                visible: root.item.page !== ""
                implicitWidth: 32
                implicitHeight: 32
                icon: "open_in_new"
                tooltip: Translation.tr("Open in the store")
                onClicked: Qt.openUrlExternally(root.item.page)
            }
        }

        // Progress of this theme's download.
        ColumnLayout {
            visible: root.busy
            Layout.fillWidth: true
            spacing: 4
            Rectangle {
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
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.store.status + (root.store.fraction >= 0 && root.store.fraction < 1 ? ` ${Math.round(root.store.fraction * 100)}%` : "")
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
                IconButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "close"
                    tooltip: Translation.tr("Stop the download")
                    onClicked: root.store.cancelInstall()
                }
            }
        }

        // Variants to pick from.
        Flow {
            visible: root.picking && !root.busy
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.files
                Chip {
                    required property var modelData
                    text: root.variant(modelData)
                    icon: "download"
                    onClicked: {
                        root.picking = false;
                        root.store.install(root.item, modelData.index);
                    }
                }
            }
        }

        StyledText {
            visible: root.files.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translation.tr("No archive to download: install it from its page")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        Flow {
            visible: !root.busy && root.files.length > 0
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.have
                M3Button {
                    required property string modelData
                    readonly property bool inUse: modelData === root.store.current
                    tonal: inUse
                    icon: inUse ? "check" : "brush"
                    text: inUse ? Translation.tr("In use") : (root.have.length > 1 ? Translation.tr("Apply %1").arg(modelData) : Translation.tr("Apply"))
                    onClicked: if (!inUse) root.store.apply(modelData)
                }
            }
            M3Button {
                tonal: root.have.length > 0
                enabled: root.store.installing === ""
                icon: root.picking ? "close" : "download"
                text: root.picking ? Translation.tr("Cancel")
                    : root.files.length > 1 ? Translation.tr("Install…")
                    : root.have.length > 0 ? Translation.tr("Reinstall") : Translation.tr("Install")
                onClicked: {
                    if (root.files.length > 1)
                        root.picking = !root.picking;
                    else
                        root.store.install(root.item, root.files[0].index);
                }
            }
        }
    }
}
