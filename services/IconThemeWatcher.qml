import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// KDE's icon theme (System Settings → Icons, kdeglobals [Icons] Theme). When it changes under the
// running shell, Qt's icon lookup in this process breaks: icons that weren't drawn yet (a new size,
// a new window) come out blank, and stay blank after switching back. Only a fresh process has
// working icons again, so the shell restarts itself after the theme changes (appearance.restartOnIconTheme).
Scope {
    id: root

    property string theme: ""
    property bool known: false

    function parse(text) {
        const m = text.match(/^\[Icons\][^\[]*?^Theme=(.*)$/m);
        return m ? m[1].trim() : "";
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const now = root.parse(text());
            if (root.known && now !== root.theme && Config.options.appearance.restartOnIconTheme)
                restartLater.restart();
            root.theme = now;
            root.known = true;
        }
    }

    // A theme switch writes the file a few times: wait for it to settle.
    Timer {
        id: restartLater
        interval: 1500
        onTriggered: {
            console.log("IconThemeWatcher: the icon theme changed, restarting the shell");
            Quickshell.execDetached(["sh", "-c", `sleep 0.3; qs -c hi-shell kill; exec setsid "${Quickshell.shellDir}/run.sh" -d`]);
        }
    }
}
