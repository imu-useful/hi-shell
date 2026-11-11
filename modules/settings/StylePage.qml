import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Looks, palette, shape and size, surfaces, fonts and the colors of other apps.
ColumnLayout {
    readonly property var a: Config.options.appearance
    spacing: 24

    Section {
        icon: "style"
        title: Translation.tr("Looks")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            text: Translation.tr("Looks: one tap sets shape, surfaces, text and motion together")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Flow {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8
            Repeater {
                model: Looks.names
                Chip {
                    required property string modelData
                    readonly property var look: Looks.all[modelData]
                    text: look?.builtin ? Translation.tr(modelData) : modelData
                    icon: look?.icon ?? "palette"
                    closable: look ? !look.builtin : false
                    onClicked: Looks.apply(modelData)
                    onCloseClicked: Looks.remove(modelData)
                }
            }
        }
        TextRow {
            icon: "bookmark_add"
            title: Translation.tr("Save this look")
            subtitle: Translation.tr("Type a name and press Enter; the x on a look of yours removes it")
            placeholder: Translation.tr("My look")
            onEdited: text => { if (text.trim() !== "" && Looks.save(text.trim())) value = ""; }
        }
        M3Button {
            Layout.margins: 14
            text: Translation.tr("Reset shape, size and palette")
            onClicked: ["cornerScale", "fontScale", "density", "seedColor", "contrast", "surfaceStyle", "borderWidth", "textWeight", "letterSpacing"].forEach(k => Config.reset("appearance." + k))
        }
    }

    Section {
        icon: "palette"
        title: Translation.tr("Palette")

        TextRow {
            icon: "colorize"
            title: Translation.tr("Seed color")
            subtitle: Translation.tr("A color like #ff6a00 to make the palette from; empty = from the wallpaper")
            placeholder: "#ff6a00"
            value: a.seedColor
            onEdited: text => {
                const t = text.trim();
                a.seedColor = t === "" || /^#[0-9a-fA-F]{6}$/.test(t) ? t : a.seedColor;
            }
        }
        SliderRow {
            icon: "contrast"
            title: Translation.tr("Contrast")
            value: Math.round(a.contrast * 100)
            from: -100; to: 100; step: 10; suffix: "%"
            onMoved: value => a.contrast = value / 100
        }
    }

    Section {
        icon: "straighten"
        title: Translation.tr("Shape & size")

        ChoiceRow {
            icon: "density_medium"
            title: Translation.tr("Density")
            subtitle: Translation.tr("The spacing between and inside elements")
            value: a.density
            options: [{ value: "compact", text: Translation.tr("Compact") }, { value: "comfortable", text: Translation.tr("Comfortable") }, { value: "spacious", text: Translation.tr("Spacious") }]
            onSelected: value => a.density = value
        }
        SliderRow {
            icon: "rounded_corner"
            title: Translation.tr("Corner roundness")
            subtitle: Translation.tr("0 makes every corner square")
            value: Math.round(a.cornerScale * 100)
            from: 0; to: 200; step: 5; suffix: "%"
            onMoved: value => a.cornerScale = value / 100
        }
        SliderRow {
            icon: "format_size"
            title: Translation.tr("Text size")
            value: Math.round(a.fontScale * 100)
            from: 60; to: 200; step: 5; suffix: "%"
            onMoved: value => a.fontScale = value / 100
        }
        SliderRow {
            icon: "rounded_corner"
            title: Translation.tr("Screen corners")
            subtitle: Translation.tr("0 turns them off")
            value: a.screenCorners
            from: 0; to: 32; suffix: Translation.tr(" px")
            onMoved: value => a.screenCorners = value
        }
    }

    Section {
        icon: "layers"
        title: Translation.tr("Surfaces")

        ChoiceRow {
            icon: "layers"
            title: Translation.tr("Surfaces")
            subtitle: Translation.tr("Tonal: by tone; glass: always see-through; flat: solid with an edge")
            value: a.surfaceStyle
            options: [{ value: "tonal", text: Translation.tr("Tonal") }, { value: "glass", text: Translation.tr("Glass") }, { value: "flat", text: Translation.tr("Flat") }]
            onSelected: value => a.surfaceStyle = value
        }
        SliderRow {
            icon: "border_style"
            title: Translation.tr("Outline")
            subtitle: Translation.tr("Width of the edge of panels and cards; auto follows the surface")
            value: a.borderWidth
            from: -1; to: 4; step: 1; suffix: " px"
            onMoved: value => a.borderWidth = value
        }
        SwitchRow {
            icon: "blur_on"
            title: Translation.tr("Transparency")
            checked: a.transparency
            onToggled: checked => a.transparency = checked
        }
        SliderRow {
            visible: a.transparency
            icon: "opacity"
            title: Translation.tr("Panel transparency")
            value: Math.round(a.transparencyLevel * 100)
            from: 0; to: 50; suffix: "%"
            onMoved: value => a.transparencyLevel = value / 100
        }
        SwitchRow {
            icon: "album"
            title: Translation.tr("Blurred cover behind the player")
            subtitle: Translation.tr("The playing track's cover, blurred, fills the media cards")
            checked: a.coverBackdrop
            onToggled: checked => a.coverBackdrop = checked
        }
        ChoiceRow {
            icon: "menu_open"
            title: Translation.tr("Context menus")
            subtitle: Translation.tr("The tray's right-click menus")
            value: a.contextMenu
            options: [{ value: "material", text: Translation.tr("New") }, { value: "caelestia", text: "Caelestia" }, { value: "standard", text: Translation.tr("Standard") }]
            onSelected: value => a.contextMenu = value
        }
    }

    Section {
        icon: "text_fields"
        title: Translation.tr("Fonts")

        TextRow { icon: "font_download"; title: Translation.tr("Interface"); value: a.fonts.main; onEdited: text => a.fonts.main = text || "Google Sans Flex" }
        TextRow { icon: "title"; title: Translation.tr("Titles"); value: a.fonts.title; onEdited: text => a.fonts.title = text || "Google Sans Flex" }
        TextRow { icon: "code"; title: Translation.tr("Monospace"); value: a.fonts.mono; onEdited: text => a.fonts.mono = text || "JetBrains Mono" }
        ChoiceRow {
            icon: "format_bold"
            title: Translation.tr("Text weight")
            value: a.textWeight
            options: [{ value: "light", text: Translation.tr("Light") }, { value: "normal", text: Translation.tr("Normal") }, { value: "medium", text: Translation.tr("Medium") }]
            onSelected: value => a.textWeight = value
        }
        SliderRow {
            icon: "format_letter_spacing"
            title: Translation.tr("Letter spacing")
            value: Math.round(a.letterSpacing * 10)
            from: -10; to: 30; step: 1; decimals: 0; suffix: " ‰"
            onMoved: value => a.letterSpacing = value / 10
        }
    }

    Section {
        icon: "format_paint"
        title: Translation.tr("App themes")

        SwitchRow {
            icon: "web_asset"
            title: Translation.tr("GTK apps")
            subtitle: Translation.tr("The wallpaper's colors in GTK 3 / 4 apps (a block in ~/.config/gtk-3.0 and gtk-4.0 gtk.css; off removes it)")
            checked: Config.options.appThemes.gtk
            onToggled: checked => Config.options.appThemes.gtk = checked
        }
        SwitchRow {
            visible: Config.options.settingsAdvanced
            icon: "contrast"
            title: Translation.tr("Switch GTK apps with dark and light")
            checked: Config.options.appearance.gtkColorScheme
            onToggled: checked => Config.options.appearance.gtkColorScheme = checked
        }
        SwitchRow {
            icon: "terminal"
            title: Translation.tr("Neovim")
            subtitle: Translation.tr("Writes the hi-shell color scheme: use :colorscheme hi-shell in Neovim")
            checked: Config.options.appThemes.neovim
            onToggled: checked => Config.options.appThemes.neovim = checked
        }
        SwitchRow {
            icon: "palette"
            title: Translation.tr("Themed app icons")
            subtitle: Translation.tr("The apps' icons in one color, the wallpaper's primary: in the dock, the bar's workspaces and the launcher")
            checked: Config.options.appearance.themedIcons
            onToggled: checked => Config.options.appearance.themedIcons = checked
        }
        SwitchRow {
            visible: Config.options.settingsAdvanced
            icon: "restart_alt"
            title: Translation.tr("Restart when the icon theme changes")
            subtitle: Translation.tr("Icons break in a running shell when KDE's icon theme changes, so it restarts")
            checked: Config.options.appearance.restartOnIconTheme
            onToggled: checked => Config.options.appearance.restartOnIconTheme = checked
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("Terminals, btop, fish and starship follow the palette without a switch.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }
}
