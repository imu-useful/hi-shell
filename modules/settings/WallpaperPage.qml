import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// The wallpaper, its frame, and online wallpapers.
ColumnLayout {
    id: root

    readonly property var d: Config.options.desktop
    spacing: 24

    Section {
        icon: "wallpaper"
        title: Translation.tr("Wallpaper")

        SwitchRow { icon: "wallpaper"; title: Translation.tr("Draw the wallpaper"); subtitle: Translation.tr("Turn off if another tool (swww, hyprpaper) draws it"); checked: root.d.wallpaper; onToggled: checked => root.d.wallpaper = checked }
        SwitchRow { icon: "animated_images"; title: Translation.tr("Play live wallpapers"); subtitle: Translation.tr("A video or gif wallpaper moves; it pauses while a window covers the desktop. Off: its still picture"); checked: Config.options.wallpapers.animate; onToggled: checked => Config.options.wallpapers.animate = checked }
        StepperRow {
            icon: "shuffle"
            title: Translation.tr("Slideshow")
            subtitle: Config.options.wallpapers.slideshowMinutes > 0 ? Translation.tr("A random wallpaper every %1 minutes").arg(Config.options.wallpapers.slideshowMinutes) : Translation.tr("Off: 0 minutes")
            value: Config.options.wallpapers.slideshowMinutes
            step: 5
            from: 0
            to: 180
            onChanged: value => Config.options.wallpapers.slideshowMinutes = value
        }
        TextRow {
            visible: Config.options.settingsAdvanced
            icon: "download"
            title: Translation.tr("Download folder")
            subtitle: Translation.tr("Where wallpapers from Wallhaven and Unsplash are saved")
            value: Config.options.wallpapers.downloadDirectory
            fieldWidth: 260
            onEdited: text => Config.options.wallpapers.downloadDirectory = text.trim() || "~/Pictures/Wallpapers/online"
        }
        SwitchRow {
            icon: "album"
            title: Translation.tr("Cover mode")
            subtitle: Translation.tr("The playing track's cover instead of the wallpaper, colors included")
            checked: root.d.coverMode
            onToggled: checked => root.d.coverMode = checked
        }
        SwitchRow {
            icon: "layers_clear"
            title: Translation.tr("Clean desktop")
            subtitle: Translation.tr("With windows open: sharp wallpaper, widgets and frame hidden")
            checked: root.d.focusMode
            onToggled: checked => root.d.focusMode = checked
        }
    }

    Section {
        icon: "crop_free"
        title: Translation.tr("Wallpaper frame")

        FramePicker {
            Layout.fillWidth: true
            Layout.margins: 12
            current: Config.options.wallpapers.frame
            onPicked: id => Config.options.wallpapers.frame = id
        }
        ListRow {
            Layout.fillWidth: true
            icon: "open_with"
            title: Translation.tr("Move the frame")
            subtitle: Translation.tr("Drag it on the desktop, in edit mode")
            M3Button {
                tonal: true
                visible: Config.options.wallpapers.frameX !== 0.5 || Config.options.wallpapers.frameY !== 0.5
                text: Translation.tr("Center")
                onClicked: {
                    Config.options.wallpapers.frameX = 0.5;
                    Config.options.wallpapers.frameY = 0.5;
                }
            }
            M3Button {
                tonal: true
                text: Translation.tr("Move")
                onClicked: {
                    ShellState.settingsOpen = false;
                    ShellState.desktopEditing = true;
                }
            }
        }
        SwitchRow {
            icon: "graphic_eq"
            title: Translation.tr("Move to the music")
            subtitle: Translation.tr("The frame turns and pulses to the bass while something plays")
            checked: Config.options.wallpapers.frameDance
            onToggled: checked => Config.options.wallpapers.frameDance = checked
        }
        SwitchRow {
            enabled: Config.options.wallpapers.frameDance
            icon: "shapes"
            title: Translation.tr("Change shape on the beat")
            tag: Translation.tr("Beta")
            subtitle: Translation.tr("On every beat the frame morphs into another shape, and goes back to yours when the music stops")
            checked: Config.options.wallpapers.frameBeatShape
            onToggled: checked => Config.options.wallpapers.frameBeatShape = checked
        }
        TextRow {
            icon: "image"
            title: Translation.tr("Image frame widget picture")
            subtitle: Translation.tr("Empty = the wallpaper")
            value: root.d.image
            fieldWidth: 300
            placeholder: "~/Pictures/photo.jpg"
            onEdited: text => root.d.image = text.replace(/^~/, Paths.home)
        }
    }

    Section {
        icon: "public"
        title: Translation.tr("Online wallpapers")

        TextRow {
            icon: "key"
            title: Translation.tr("Unsplash access key")
            subtitle: Translation.tr("Free at unsplash.com/developers; enables Unsplash in the picker")
            value: Config.options.wallpapers.unsplashKey
            secret: true
            fieldWidth: 300
            onEdited: text => Config.options.wallpapers.unsplashKey = text.trim()
        }
        TextRow {
            icon: "key"
            title: Translation.tr("Wallhaven API key")
            subtitle: Translation.tr("Optional")
            value: Config.options.wallpapers.wallhavenKey
            secret: true
            fieldWidth: 300
            onEdited: text => Config.options.wallpapers.wallhavenKey = text.trim()
        }
        TextRow {
            icon: "folder"
            title: Translation.tr("Wallpaper folders")
            subtitle: Translation.tr("Comma separated")
            value: Config.options.wallpapers.directories.join(", ")
            fieldWidth: 300
            onEdited: text => {
                Config.options.wallpapers.directories = text.split(",").map(d => d.trim()).filter(d => d);
                Wallpapers.scan();
            }
        }
    }
}
