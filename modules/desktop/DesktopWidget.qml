import QtQuick
import qs.common
import qs.common.widgets
import "Layout.js" as DesktopLayout

// Places one desktop widget from Config desktop.layout. In edit mode it can
// be dragged (snapping to a 16 px grid); the position is saved as screen fractions.
Item {
    id: root

    required property string widgetId
    property bool editing: false
    // Created only while the widget is enabled and its screen shows widgets;
    // hidden widgets would otherwise keep updating in the background.
    default property Component content

    readonly property var entry: DesktopLayout.entry(Config.options.desktop.layout, widgetId)
    readonly property int grid: 16

    readonly property bool live: entry.enabled && (parent?.visible ?? false)

    visible: entry.enabled
    width: holder.childrenRect.width
    height: holder.childrenRect.height
    x: Math.round(entry.x * (parent?.width ?? 0))
    y: Math.round(entry.y * (parent?.height ?? 0))

    function save() {
        const w = parent.width, h = parent.height;
        const nx = Math.max(0, Math.min(w - width, Math.round(x / grid) * grid));
        const ny = Math.max(0, Math.min(h - height, Math.round(y / grid) * grid));
        const layout = Object.assign({}, Config.options.desktop.layout);
        layout[widgetId] = Object.assign({}, entry, { x: nx / w, y: ny / h });
        Config.options.desktop.layout = layout;
        // Dragging replaced the position bindings; follow the config again.
        x = Qt.binding(() => Math.round(entry.x * (parent?.width ?? 0)));
        y = Qt.binding(() => Math.round(entry.y * (parent?.height ?? 0)));
    }

    Item {
        id: holder

        Loader {
            active: root.live
            sourceComponent: root.content
        }
    }

    // Edit mode: outline, name and drag anywhere on the widget.
    Rectangle {
        visible: root.editing
        anchors.fill: parent
        anchors.margins: -4
        radius: Appearance.rounding.extraLarge + 4
        color: drag.active ? Qt.alpha(Colors.m3primary, 0.12) : "transparent"
        border.width: 2
        border.color: drag.active ? Colors.m3primary : Qt.alpha(Colors.m3outline, 0.8)

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            implicitWidth: label.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            color: Colors.m3primary
            StyledText {
                id: label
                anchors.centerIn: parent
                text: Translation.tr(DesktopLayout.names[root.widgetId])
                font.pixelSize: Appearance.font.size.labelSmall
                color: Colors.m3onPrimary
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }

    DragHandler {
        id: drag
        enabled: root.editing
        target: root
        onActiveChanged: if (!active) root.save()
    }
}
