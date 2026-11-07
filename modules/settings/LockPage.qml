import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Lock screen: which parts show, the clock, and the background.
ColumnLayout {
    id: root

    readonly property var l: Config.options.lock
    spacing: 24
    readonly property bool builtin: l.mode === "builtin"

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
        icon: "lock"
        title: Translation.tr("Lock screen")

        ChoiceRow {
            icon: "tune"
            title: Translation.tr("Type")
            subtitle: Translation.tr("hi-shell's own, your hyprlock config, or another locker")
            value: root.l.mode
            options: [{ value: "builtin", text: "hi-shell" }, { value: "file", text: Translation.tr("My hyprlock config") }, { value: "command", text: Translation.tr("My command") }]
            onSelected: value => root.l.mode = value
        }
        TextRow {
            visible: root.l.mode === "file"
            icon: "description"
            title: Translation.tr("Config file")
            subtitle: Translation.tr("Sourced by the lock screen, also when the screen locks by itself")
            placeholder: "~/.config/hypr/hyprlock.conf"
            value: root.l.customConfig
            fieldWidth: 280
            onEdited: text => root.l.customConfig = text.trim()
        }
        TextRow {
            visible: root.l.mode === "command"
            icon: "terminal"
            title: Translation.tr("Lock command")
            subtitle: Translation.tr("Run by Lock; the screen locking by itself (hypridle) still uses hyprlock")
            placeholder: "swaylock"
            value: root.l.customCommand
            fieldWidth: 280
            onEdited: text => root.l.customCommand = text.trim()
        }
    }

    Section {
        id: idleSection
        readonly property var i: Config.options.idle
        icon: "bedtime"
        title: Translation.tr("Idle")

        SwitchRow {
            icon: "timer"
            title: Translation.tr("Lock, turn the screen off and sleep by itself")
            subtitle: Translation.tr("Off: your own hypridle config decides. On: hi-shell runs hypridle with the times below")
            checked: idleSection.i.manage
            onToggled: checked => idleSection.i.manage = checked
        }
        StepperRow { visible: idleSection.i.manage; icon: "lock_clock"; title: Translation.tr("Lock after, minutes (0 = never)"); value: idleSection.i.lockMin; from: 0; to: 600; onChanged: v => idleSection.i.lockMin = v }
        StepperRow { visible: idleSection.i.manage; icon: "desktop_access_disabled"; title: Translation.tr("Screen off after, minutes"); value: idleSection.i.screenOffMin; from: 0; to: 600; onChanged: v => idleSection.i.screenOffMin = v }
        StepperRow { visible: idleSection.i.manage; icon: "bedtime"; title: Translation.tr("Suspend after, minutes"); value: idleSection.i.suspendMin; from: 0; to: 600; onChanged: v => idleSection.i.suspendMin = v }
        SwitchRow {
            visible: idleSection.i.manage && Battery.available
            icon: "battery_android_5"
            title: Translation.tr("Other times on battery")
            checked: idleSection.i.separateBattery
            onToggled: checked => idleSection.i.separateBattery = checked
        }
        StepperRow { visible: idleSection.i.manage && idleSection.i.separateBattery && Battery.available; icon: "lock_clock"; title: Translation.tr("On battery: lock after, minutes"); value: idleSection.i.batLockMin; from: 0; to: 600; onChanged: v => idleSection.i.batLockMin = v }
        StepperRow { visible: idleSection.i.manage && idleSection.i.separateBattery && Battery.available; icon: "desktop_access_disabled"; title: Translation.tr("On battery: screen off after, minutes"); value: idleSection.i.batScreenOffMin; from: 0; to: 600; onChanged: v => idleSection.i.batScreenOffMin = v }
        StepperRow { visible: idleSection.i.manage && idleSection.i.separateBattery && Battery.available; icon: "bedtime"; title: Translation.tr("On battery: suspend after, minutes"); value: idleSection.i.batSuspendMin; from: 0; to: 600; onChanged: v => idleSection.i.batSuspendMin = v }
    }

    Section {
        visible: root.builtin
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
        visible: root.builtin
        icon: "palette"
        title: Translation.tr("Look")

        ChoiceRow {
            icon: "align_horizontal_center"
            title: Translation.tr("Layout")
            value: root.l.align
            options: [{ value: "left", text: Translation.tr("Left") }, { value: "center", text: Translation.tr("Center") }, { value: "right", text: Translation.tr("Right") }]
            onSelected: value => root.l.align = value
        }
        ChoiceRow {
            icon: "colorize"
            title: Translation.tr("Accent color")
            subtitle: Translation.tr("The clock, the avatar ring and the now playing icon")
            value: root.l.accent
            options: [{ value: "primary", text: Translation.tr("Primary") }, { value: "secondary", text: Translation.tr("Secondary") }, { value: "tertiary", text: Translation.tr("Tertiary") }]
            onSelected: value => root.l.accent = value
        }
        TextRow {
            icon: "edit_note"
            title: Translation.tr("Message")
            subtitle: Translation.tr("A line of your own under the date")
            value: root.l.message
            fieldWidth: 240
            onEdited: text => root.l.message = text.trim()
        }
        SliderRow {
            visible: root.l.avatar
            icon: "account_circle"
            title: Translation.tr("Avatar size")
            value: root.l.avatarSize
            from: 64; to: 180; step: 4; suffix: " px"
            onMoved: value => root.l.avatarSize = value
        }
        SliderRow {
            icon: "password"
            title: Translation.tr("Password field width")
            value: root.l.fieldWidth
            from: 200; to: 600; step: 10; suffix: " px"
            onMoved: value => root.l.fieldWidth = value
        }
        ChoiceRow {
            icon: "rounded_corner"
            title: Translation.tr("Password field corners")
            value: root.l.fieldShape
            options: [{ value: "round", text: Translation.tr("Rounded") }, { value: "square", text: Translation.tr("Square") }]
            onSelected: value => root.l.fieldShape = value
        }
        SliderRow {
            icon: "line_weight"
            title: Translation.tr("Password field outline")
            value: root.l.fieldOutline
            from: 0; to: 8; step: 1; suffix: " px"
            onMoved: value => root.l.fieldOutline = value
        }
        SwitchRow {
            icon: "more_horiz"
            title: Translation.tr("Dots while typing")
            subtitle: Translation.tr("Off: nothing shows as you type")
            checked: root.l.fieldDots
            onToggled: checked => root.l.fieldDots = checked
        }
    }

    Section {
        visible: root.builtin
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
        visible: root.builtin
        icon: "calendar_today"
        title: Translation.tr("Date")

        TextRow {
            icon: "event"
            title: Translation.tr("Date format")
            subtitle: Translation.tr("date format, e.g. %A, %-d %B or %d.%m.%Y")
            value: root.l.dateFormat
            fieldWidth: 160
            onEdited: text => {
                const f = text.trim();
                if (/^[%A-Za-z0-9:.,\- ]{1,32}$/.test(f))
                    root.l.dateFormat = f;
            }
        }
    }

    Section {
        visible: root.builtin
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
            visible: root.l.wallpaper && root.l.blurPasses > 0
            icon: "lens_blur"
            title: Translation.tr("Blur radius")
            value: root.l.blurSize
            from: 1; to: 20; step: 1
            onMoved: value => root.l.blurSize = value
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
