import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// A list of options that are on and in an order (the chips), with the ones that are off below to add.
// Click a chip to select it and move it with the arrows; the cross turns it off.
//   options: [{ id, text, icon }]   value: the ids that are on, in order   minimum: how few may stay on
ColumnLayout {
    id: root

    property var options: []
    property var value: []
    property int minimum: 1
    property int selected: -1

    signal changed(var list)

    readonly property var on: Array.from(value).filter(id => options.some(o => o.id === id))
    readonly property var off: options.filter(o => !on.includes(o.id))

    function info(id) {
        return options.find(o => o.id === id) ?? { id, text: id, icon: "widgets" };
    }
    function move(by) {
        const l = [...on], i = selected, j = i + by;
        if (i < 0 || j < 0 || j >= l.length)
            return;
        [l[i], l[j]] = [l[j], l[i]];
        selected = j;
        changed(l);
    }

    Layout.fillWidth: true
    Layout.margins: 10
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        visible: root.selected >= 0
        Item { Layout.fillWidth: true }
        IconButton {
            implicitWidth: 32
            implicitHeight: 32
            icon: "arrow_back"
            enabled: root.selected > 0
            onClicked: root.move(-1)
        }
        IconButton {
            implicitWidth: 32
            implicitHeight: 32
            icon: "arrow_forward"
            enabled: root.selected < root.on.length - 1
            onClicked: root.move(1)
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.on

            Chip {
                required property string modelData
                required property int index
                icon: root.info(modelData).icon
                text: root.info(modelData).text
                selected: root.selected === index
                closable: root.on.length > root.minimum
                onClicked: root.selected = root.selected === index ? -1 : index
                onCloseClicked: {
                    root.selected = -1;
                    root.changed(root.on.filter(id => id !== modelData));
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.off.length > 0
        spacing: 6

        Repeater {
            model: root.off

            Chip {
                required property var modelData
                icon: "add"
                text: modelData.text
                onClicked: root.changed([...root.on, modelData.id])
            }
        }
    }
}
