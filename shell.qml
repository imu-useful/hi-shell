//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.modules

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
