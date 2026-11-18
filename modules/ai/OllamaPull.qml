import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Downloads an Ollama model by name (ollama.com/library), with a progress bar; under the chat's model list.
ColumnLayout {
    id: root

    spacing: 6

    function start() {
        if (name.text.trim() !== "")
            Ollama.pull(name.text);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 18
            color: Colors.m3surfaceContainerHighest

            TextInput {
                id: name
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyMedium
                color: Colors.m3onSurface
                clip: true
                selectByMouse: true
                enabled: !Ollama.busy
                onAccepted: root.start()

                StyledText {
                    visible: name.text === ""
                    text: Translation.tr("Download a model: llama3.2, qwen3:4b…")
                    color: Colors.m3outline
                }
            }
        }
        IconButton {
            implicitWidth: 36
            implicitHeight: 36
            icon: Ollama.busy ? "close" : "download"
            tooltip: Ollama.busy ? Translation.tr("Stop the download") : Translation.tr("Download")
            onClicked: Ollama.busy ? Ollama.cancelPull() : root.start()
        }
    }

    Rectangle {
        visible: Ollama.busy
        Layout.fillWidth: true
        implicitHeight: 4
        radius: 2
        color: Colors.m3surfaceContainerHighest

        Rectangle {
            width: parent.width * Math.max(0, Ollama.fraction)
            height: parent.height
            radius: 2
            color: Colors.m3primary
        }
    }

    StyledText {
        visible: text !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: Appearance.font.size.labelMedium
        color: Ollama.error !== "" ? Colors.m3error : Colors.m3onSurfaceVariant
        text: Ollama.error !== "" ? Ollama.error
            : Ollama.busy ? `${Ollama.pulling}: ${Ollama.status}${Ollama.fraction >= 0 ? ` ${Math.round(Ollama.fraction * 100)}%` : ""}`
            : ""
    }
}
