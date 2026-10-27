import QtQuick
import qs.common
import qs.common.widgets
import "Layout.js" as DesktopLayout

// Places one desktop widget from Config desktop.layout. In edit mode it can be
// dragged: its edges and center snap to other widgets and the screen (with guide
// lines on the parent's guideX / guideY), else to a 16 px grid. The position is
// saved as screen fractions. The corner handle resizes it: the size is a scale
// factor (layout `scale`, 1 = normal) applied to the whole widget.
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

    // Startup: widgets pop in one after another, a wave from the top left corner.
    property real intro: ShellState.started ? 1 : 0
    Behavior on intro {
        SequentialAnimation {
            PauseAnimation { duration: 350 + (root.entry.x + root.entry.y) * 450 }
            SpringAnim { overshoot: 1.6 }
        }
    }
    opacity: Math.min(1, intro)
    scale: 0.6 + 0.4 * intro
    // The scale in the config, or the one being dragged (-1 when not resizing).
    property real dragScale: -1
    readonly property real sizeScale: dragScale > 0 ? dragScale : (entry.scale ?? 1)
    readonly property real minScale: 0.5
    readonly property real maxScale: 2.5
    width: holder.childrenRect.width * sizeScale
    height: holder.childrenRect.height * sizeScale
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

    function saveScale(value) {
        const layout = Object.assign({}, Config.options.desktop.layout);
        layout[widgetId] = Object.assign({}, entry, { scale: value });
        Config.options.desktop.layout = layout;
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
        scale: root.sizeScale
        transformOrigin: Item.TopLeft

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

        // Size badge while resizing, or when it isn't the normal size.
        Rectangle {
            visible: root.sizeScale !== 1
            anchors.right: parent.right
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            implicitWidth: sizeLabel.implicitWidth + 14
            implicitHeight: 22
            radius: 11
            color: Colors.m3secondaryContainer
            StyledText {
                id: sizeLabel
                anchors.centerIn: parent
                text: Math.round(root.sizeScale * 100) + "%"
                font.pixelSize: Appearance.font.size.labelSmall
                color: Colors.m3onSecondaryContainer
            }
        }

        // Resize: drag the corner (double click = back to normal size).
        Rectangle {
            id: handle
            anchors.horizontalCenter: parent.right
            anchors.verticalCenter: parent.bottom
            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            color: resize.pressed ? Colors.m3primary : Colors.m3secondaryContainer
            border.width: 2
            border.color: Colors.m3primary

            MaterialIcon {
                anchors.centerIn: parent
                icon: "open_in_full"
                iconSize: 14
                color: resize.pressed ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
            }

            MouseArea {
                id: resize
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.SizeFDiagCursor
                preventStealing: true
                property real startScale: 1
                property real startW: 1
                property real startH: 1
                property point startPos

                onPressed: mouse => {
                    startScale = root.sizeScale;
                    startW = Math.max(1, root.width);
                    startH = Math.max(1, root.height);
                    startPos = mapToItem(root.parent, mouse.x, mouse.y);
                    root.dragScale = startScale;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const p = mapToItem(root.parent, mouse.x, mouse.y);
                    const f = ((startW + p.x - startPos.x) / startW + (startH + p.y - startPos.y) / startH) / 2;
                    const v = Math.round(startScale * f * 20) / 20;
                    root.dragScale = Math.max(root.minScale, Math.min(root.maxScale, v));
                }
                onReleased: {
                    const v = root.dragScale;
                    root.dragScale = -1;
                    // Keep it on the screen.
                    root.saveScale(Math.abs(v - 1) < 0.04 ? 1 : v);
                }
                onDoubleClicked: {
                    root.dragScale = -1;
                    root.saveScale(1);
                }
            }
        }
    }

    DragHandler {
        id: drag
        enabled: root.editing && !resize.pressed
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
