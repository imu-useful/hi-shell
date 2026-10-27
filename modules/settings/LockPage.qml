import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Lock screen: which parts show, the clock, and the background.
ColumnLayout {
    id: root

    readonly property var l: Config.options.lock
    spacing: 24

    // Chips for the elements, in the order they show on the screen (top to bottom).
    readonly property var elements: [
        { id: "clock", name: Translation.tr("Clock") },
        { id: "date", name: Translation.tr("Date") },
        { id: "greeting", name: Translation.tr("Greeting") },
        { id: "avatar", name: Translation.tr("Avatar") },
        { id: "nowPlaying", name: Translation.tr("Now playing") },
        { id: "battery", name: Translation.tr("Battery") },
        { id: "keyboardLayout", name: Translation.tr("Keyboard layout") },
        { id: "capsLockHint", name: Translation.tr("Caps Lock hint") }
    ]

    Section {
        icon: "widgets"
        title: Translation.tr("On the lock screen")

        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 6
            Repeater {
                model: root.elements
                Chip {
                    required property var modelData
                    text: modelData.name
                    selected: root.l[modelData.id]
                    onClicked: root.l[modelData.id] = !selected
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 0
            text: Translation.tr("The password field is always shown.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    Section {
        icon: "schedule"
        title: Translation.tr("Clock")

        SliderRow {
            icon: "format_size"
            title: Translation.tr("Clock size")
            value: root.l.clockSize
            from: 60; to: 200; step: 4; suffix: " px"
            onMoved: value => root.l.clockSize = value
        }
        TextRow {
            icon: "schedule"
            title: Translation.tr("Clock format")
            subtitle: Translation.tr("date format, e.g. %H:%M or %I:%M %p")
            value: root.l.clockFormat
            fieldWidth: 160
            // Only what `date` takes without quoting problems; anything else is ignored.
            onEdited: text => {
                const f = text.trim();
                if (/^[%A-Za-z0-9:.\- ]{1,24}$/.test(f))
                    root.l.clockFormat = f;
            }
        }
    }

    Section {
        icon: "wallpaper"
        title: Translation.tr("Background")

        SwitchRow {
            icon: "image"
            title: Translation.tr("Wallpaper")
            subtitle: Translation.tr("Off: a plain background in the surface color")
            checked: root.l.wallpaper
            onToggled: checked => root.l.wallpaper = checked
        }
        SliderRow {
            visible: root.l.wallpaper
            icon: "blur_on"
            title: Translation.tr("Blur")
            value: root.l.blurPasses
            from: 0; to: 6; step: 1
            onMoved: value => root.l.blurPasses = value
        }
        SliderRow {
            visible: root.l.wallpaper
            icon: "brightness_6"
            title: Translation.tr("Brightness")
            value: Math.round(root.l.brightness * 100)
            from: 0; to: 100; step: 5; suffix: "%"
            onMoved: value => root.l.brightness = value / 100
        }
    }
}
