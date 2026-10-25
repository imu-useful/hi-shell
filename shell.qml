//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.common
import qs.modules

ShellRoot {
    // Instantiate the theme service so the palette follows the wallpaper.
    readonly property var theme: Theme

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {}

    AIWidget {}

    ControlCenter {}
}
