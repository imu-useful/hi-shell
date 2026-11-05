import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.modules.bar
import qs.services

// Under the calendar: the programs using the camera or the microphone, while any does.
ColumnLayout {
    visible: Island.privacy
    spacing: 8

    StyledText {
        text: Translation.tr("In use now")
        font.pixelSize: Appearance.font.size.labelMedium
        color: Colors.m3onSurfaceVariant
    }
    PrivacyList {
        Layout.fillWidth: true
        textWidth: 240
    }
}
