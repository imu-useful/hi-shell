pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Interface language. Strings are written in English and looked up in
// translations/<code>.json (English text -> translation); missing ones stay English.
// Use Translation.tr("Text") in bindings, with .arg() for placeholders: tr("%1 updates").arg(n).
Singleton {
    id: root

    readonly property var available: [
        { code: "en", name: "English" },
        { code: "ru", name: "Русский" },
        { code: "zh", name: "中文" }
    ]

    // auto -> the first language of $LANG / $LC_MESSAGES we have, else English
    readonly property string code: {
        const chosen = Config.options.language;
        if (chosen && chosen !== "auto")
            return chosen;
        const env = (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").slice(0, 2);
        return available.some(l => l.code === env) ? env : "en";
    }
    // For dates, month and day names in the interface language.
    readonly property var locale: Qt.locale(code === "ru" ? "ru_RU" : code === "zh" ? "zh_CN" : "en_GB")

    property var strings: ({})

    function tr(text: string): string {
        const t = strings[text];
        return typeof t === "string" ? t : text;
    }

    // Count-dependent text with %1 replaced by n: trn("%1 update", "%1 updates", n).
    // Translations of `many` may be [one, few, many] (Russian plural rules) or a single string.
    function trn(one: string, many: string, n: int): string {
        const t = strings[many];
        let s = n === 1 ? one : many;
        if (Array.isArray(t) && t.length === 3) {
            const m10 = n % 10, m100 = n % 100;
            s = t[m10 === 1 && m100 !== 11 ? 0 : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? 1 : 2];
        } else if (typeof t === "string") {
            s = t;
        }
        return s.replace("%1", n);
    }

    FileView {
        path: root.code === "en" ? "" : Quickshell.shellPath(`translations/${root.code}.json`)
        printErrors: false
        onLoaded: {
            try {
                root.strings = JSON.parse(text());
            } catch (e) {
                console.warn("Translation: bad", path, e);
                root.strings = {};
            }
        }
        onPathChanged: if (!path) root.strings = {}
    }
}
