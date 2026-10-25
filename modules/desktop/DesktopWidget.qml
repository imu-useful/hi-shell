import QtQuick
import qs.common
import qs.common.widgets
import "Layout.js" as DesktopLayout

// Places one desktop widget from Config desktop.layout. In edit mode it can be
// dragged: its edges and center snap to other widgets and the screen (with guide
// lines on the parent's guideX / guideY), else to a 16 px grid. The position is
// saved as screen fractions.
Item {
    id: root

    required property string widgetId
    property bool editing: false
    // Created only while the widget is enabled and its screen shows widgets;
    // hidden widgets would otherwise keep updating in the background.
    default property Component content

    readonly property var entry: DesktopLayout.entry(Config.options.desktop.layout, widgetId)
    readonly property int grid: 16
    // How close (px) an edge has to come to another edge to snap to it.
    readonly property int snapDistance: 10
    readonly property int screenMargin: 24

    readonly property bool live: entry.enabled && (parent?.visible ?? false)

    visible: entry.enabled
    width: holder.childrenRect.width
    height: holder.childrenRect.height
    x: Math.round(entry.x * (parent?.width ?? 0))
    y: Math.round(entry.y * (parent?.height ?? 0))

    // Lines to snap to on one axis: edges and centers of the other widgets, the
    // screen margins and the screen center.
    function snapLines(horizontal) {
        const size = horizontal ? parent.width : parent.height;
        const lines = [screenMargin, size / 2, size - screenMargin];
        for (const other of parent.children) {
            if (other === root || !other.visible || other.widgetId === undefined)
                continue;
            const start = horizontal ? other.x : other.y;
            const length = horizontal ? other.width : other.height;
            lines.push(start, start + length / 2, start + length);
        }
        return lines;
    }

    // Best snap for a widget at `pos` with `length` along one axis:
    // { pos, guide } where guide is the line it snapped to, or -1 (grid).
    function snapAxis(pos, length, horizontal) {
        let best = null;
        for (const line of snapLines(horizontal)) {
            // Own start, center and end against the line.
            for (const offset of [0, length / 2, length]) {
                const d = line - (pos + offset);
                if (Math.abs(d) <= snapDistance && (best === null || Math.abs(d) < Math.abs(best.d)))
                    best = { d, line };
            }
        }
        if (best)
            return { pos: Math.round(pos + best.d), guide: best.line };
        return { pos: Math.round(pos / grid) * grid, guide: -1 };
    }

    function moveTo(px, py) {
        const sx = snapAxis(px, width, true);
        const sy = snapAxis(py, height, false);
        x = Math.max(0, Math.min(parent.width - width, sx.pos));
        y = Math.max(0, Math.min(parent.height - height, sy.pos));
        if (parent.guideX !== undefined) {
            parent.guideX = sx.guide;
            parent.guideY = sy.guide;
        }
    }

    function save() {
        const w = parent.width, h = parent.height;
        const nx = Math.max(0, Math.min(w - width, x));
        const ny = Math.max(0, Math.min(h - height, y));
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
        // Moved by hand (moveTo) so the position can snap while dragging.
        target: null
        property real startX: 0
        property real startY: 0
        onActiveChanged: {
            if (active) {
                startX = root.x;
                startY = root.y;
            } else {
                if (root.parent.guideX !== undefined)
                    root.parent.guideX = root.parent.guideY = -1;
                root.save();
            }
        }
        onTranslationChanged: if (active) root.moveTo(startX + translation.x, startY + translation.y)
    }
}
