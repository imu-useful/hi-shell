import QtQuick
import QtQuick.Layouts
import qs.common

// One bar section (left / center / right): a row (or column) of widgets
// created from their ids. Unknown ids are skipped with a warning.
GridLayout {
    id: root

    required property var bar
    required property list<string> widgets
    // id -> Component, see Bar.qml
    required property var registry

    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: bar.vertical ? -1 : 1
    columns: bar.vertical ? 1 : -1
    rowSpacing: 4
    columnSpacing: 4

    Repeater {
        model: root.widgets

        Loader {
            id: loader

            required property string modelData
            readonly property var bar: root.bar

            Layout.alignment: Qt.AlignCenter
            // activeWindow / media may shrink to fit; Layout reads these from the item.
            Layout.fillWidth: !root.bar.vertical && (item?.Layout.fillWidth ?? false)
            Layout.maximumWidth: item?.Layout.maximumWidth ?? Number.POSITIVE_INFINITY
            Layout.preferredWidth: item?.implicitWidth ?? 0
            Layout.preferredHeight: item?.implicitHeight ?? 0
            visible: item?.shown ?? false

            sourceComponent: root.registry[modelData] ?? null
            Component.onCompleted: {
                if (!root.registry[modelData])
                    console.warn(`Bar: unknown widget "${modelData}"`);
            }
        }
    }
}
