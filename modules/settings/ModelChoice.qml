import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// A model picked from the list of the chat's provider (Claude's three, or the provider's models).
// Shows the current one; a click opens the list below it.
ColumnLayout {
    id: root

    property string title: ""
    property string icon: "smart_toy"
    // The id picked, and the one used when none is (shown as the current one).
    property string current: ""
    property string fallback: ""
    signal picked(string id)

    readonly property var options: Claude.provider === "claude" ? Claude.models.filter(m => m.id !== "") : Claude.modelList
    readonly property string shown: current !== "" ? current : fallback
    readonly property string shownName: options.find(m => m.id === shown)?.name ?? shown
    property bool expanded: false

    Layout.fillWidth: true
    spacing: 0

    ListRow {
        Layout.fillWidth: true
        icon: root.icon
        title: root.title
        subtitle: Claude.provider === "claude" ? Translation.tr("Claude CLI models") : Claude.providerName
        clickable: true
        onClicked: {
            root.expanded = !root.expanded;
            if (root.expanded && Claude.provider !== "claude" && root.options.length === 0)
                Claude.loadModels();
        }
        StyledText {
            text: root.shownName || Translation.tr("Pick a model")
            color: Colors.m3primary
        }
        MaterialIcon {
            icon: root.expanded ? "expand_less" : "expand_more"
        }
    }

    Flickable {
        id: list
        visible: root.expanded
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.preferredHeight: visible ? Math.min(contentHeight, 280) : 0
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            width: list.width
            spacing: 2

            Repeater {
                model: root.options

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.rounding.small
                    color: modelData.id === root.shown ? Colors.m3primaryContainer : "transparent"

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: modelData.name ?? modelData.id
                        elide: Text.ElideRight
                    }
                    StateLayer {
                        onClicked: {
                            root.picked(modelData.id);
                            root.expanded = false;
                        }
                    }
                }
            }

            StyledText {
                visible: root.options.length === 0
                Layout.fillWidth: true
                text: Claude.modelsError !== "" ? Claude.modelsError : Translation.tr("Loading the models…")
                wrapMode: Text.Wrap
                color: Colors.m3outline
            }
        }
    }
}
