import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// An icon theme in the KDE Store: its picture, name, author, downloads and rating; Install
// (a theme shipped in several variants asks which one), the download's progress, then Apply.
Rectangle {
    id: root

    required property var item
    readonly property var have: IconStore.installedFrom(item.id, item.files.map(f => variant(f)).concat([item.name]))
    readonly property bool busy: IconStore.installing === item.id
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
                    width: parent.width * Math.max(0.04, IconStore.fraction)
                    height: parent.height
                    radius: 2
                    color: Colors.m3primary
                }
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: IconStore.status + (IconStore.fraction >= 0 && IconStore.fraction < 1 ? ` ${Math.round(IconStore.fraction * 100)}%` : "")
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
                IconButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "close"
                    tooltip: Translation.tr("Stop the download")
                    onClicked: IconStore.cancelInstall()
                }
            }
        }

        // Variants to pick from.
        Flow {
            visible: root.picking && !root.busy
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.item.files
                Chip {
                    required property var modelData
                    text: root.variant(modelData)
                    icon: "download"
                    onClicked: {
                        root.picking = false;
                        IconStore.install(root.item, modelData.index);
                    }
                }
            }
        }

        StyledText {
            visible: root.item.files.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translation.tr("No archive to download: install it from its page")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        Flow {
            visible: !root.busy && root.item.files.length > 0
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.have
                M3Button {
                    required property string modelData
                    readonly property bool inUse: modelData === IconStore.current
                    tonal: inUse
                    icon: inUse ? "check" : "brush"
                    text: inUse ? Translation.tr("In use") : (root.have.length > 1 ? Translation.tr("Apply %1").arg(modelData) : Translation.tr("Apply"))
                    onClicked: if (!inUse) IconStore.apply(modelData)
                }
            }
            M3Button {
                tonal: root.have.length > 0
                enabled: IconStore.installing === ""
                icon: root.picking ? "close" : "download"
                text: root.picking ? Translation.tr("Cancel")
                    : root.item.files.length > 1 ? Translation.tr("Install…")
                    : root.have.length > 0 ? Translation.tr("Reinstall") : Translation.tr("Install")
                onClicked: {
                    if (root.item.files.length > 1)
                        root.picking = !root.picking;
                    else
                        IconStore.install(root.item, root.item.files[0].index);
                }
            }
        }
    }
}
