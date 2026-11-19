pragma Singleton

import QtQuick
import Quickshell

// Who the shell says you are: the name and the avatar picked in Settings > General > Profile,
// falling back to the system user name and ~/.face.
Singleton {
    readonly property string name: Config.options.profile.name.trim() || Quickshell.env("USER")
    readonly property string avatarPath: {
        const p = Config.options.profile.avatar.trim();
        if (!p) return `${Paths.home}/.face`;
        return p.startsWith("~/") ? Paths.home + p.slice(1) : p;
    }
    readonly property string avatarSource: `file://${avatarPath}`
}
