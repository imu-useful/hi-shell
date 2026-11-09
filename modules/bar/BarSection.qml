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
    // The Dynamic Island (the clock) takes the bar over: 0..1, how far the other widgets have gone.
    // They shrink and fade while moving towards the island: the ones before it (left / top) go on
    // towards the end, the ones after it back. `side` is this section's place against the section that holds
    // the island: -1 before it, 1 after it, 0 the same section (then `islandIndex` tells which widgets are before).
    property real collapse: 0
    property int side: 0
    property int islandIndex: -1
    // The Loader of the island (the clock) when it is in this section.
    property Item islandLoader: null

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
            required property int index
            readonly property var bar: root.bar
            // "resources#disks": the type before the #, the options of this copy in Config bar.instances.
            readonly property string type: modelData.split("#")[0]
            readonly property var instance: modelData.includes("#") ? (Config.options.bar.instances?.[modelData] ?? ({})) : ({})

            readonly property bool isIsland: modelData === "clock" && root.side === 0
            // +1: moves on towards the end of the bar while going, -1: back.
            readonly property int dir: root.side !== 0 ? -root.side : (index < root.islandIndex ? 1 : -1)
            readonly property real keep: isIsland ? 1 : 1 - root.collapse

            Layout.alignment: Qt.AlignCenter
            // activeWindow / media may shrink to fit; Layout reads these from the item.
            Layout.fillWidth: !root.bar.vertical && (item?.Layout.fillWidth ?? false) && root.collapse === 0
            Layout.maximumWidth: root.collapse > 0 ? (item?.implicitWidth ?? 0) : (item?.Layout.maximumWidth ?? Number.POSITIVE_INFINITY)
            Layout.preferredWidth: (item?.implicitWidth ?? 0) * (root.bar.vertical ? 1 : keep)
            Layout.preferredHeight: (item?.implicitHeight ?? 0) * (root.bar.vertical ? keep : 1)
            visible: (item?.shown ?? false) && keep > 0.001
            opacity: keep
            transform: Translate {
                x: root.bar.vertical ? 0 : loader.dir * (1 - loader.keep) * 40
                y: root.bar.vertical ? loader.dir * (1 - loader.keep) * 40 : 0
            }

            sourceComponent: root.registry[type] ?? null
            Component.onCompleted: {
                if (isIsland)
                    root.islandLoader = loader;
                if (!root.registry[type])
                    console.warn(`Bar: unknown widget "${modelData}"`);
            }
        }
    }
}
