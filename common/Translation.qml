pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Plural.js" as Plural

// Interface language. Strings are written in English and looked up in
// translations/<code>.json (English text -> translation); missing ones stay English.
// Languages made with AI (services/LanguageMaker.qml) are in ~/.config/hi-shell/translations.
// Use Translation.tr("Text") in bindings, with .arg() for placeholders: tr("%1 updates").arg(n).
Singleton {
    id: root

    readonly property var builtin: [
        { code: "en", name: "English" },
        { code: "ru", name: "Русский" },
        { code: "de", name: "Deutsch" }
    ]
    readonly property var available: [...builtin, ...Config.options.customLanguages.filter(l => !builtin.some(b => b.code === l.code))]
    readonly property bool isBuiltin: builtin.some(b => b.code === code)
    readonly property string file: isBuiltin ? Quickshell.shellPath(`translations/${code}.json`) : `${Config.dir}/translations/${code}.json`

    // auto -> the first language of $LANG / $LC_MESSAGES we have, else English
    readonly property string code: {
        // HI_SHELL_LANG overrides the setting (tools/render_keynote.sh renders the video in English)
        const forced = Quickshell.env("HI_SHELL_LANG");
        if (forced)
            return forced;
        const chosen = Config.options.language;
        if (chosen && chosen !== "auto")
            return chosen;
        const env = (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").slice(0, 2);
        return available.some(l => l.code === env) ? env : "en";
    }
    // The system locale of each built-in language (dates, month and day names); the rest read English dates.
    readonly property var localeNames: ({ ru: "ru_RU", de: "de_DE" })
    // For dates, month and day names in the interface language.
    readonly property var locale: Qt.locale(localeNames[code] ?? "en_GB")

    property var strings: ({})

    function tr(text: string): string {
        const t = strings[text];
        return typeof t === "string" ? t : text;
    }

    // Count-dependent text with %1 replaced by n: trn("%1 update", "%1 updates", n).
    // The translation of `many` is a list of forms in the language's order (common/Plural.js: Russian
    // has three, German two) or a single string for "other"; then `one`'s own translation serves n = 1.
    function trn(one: string, many: string, n: int): string {
        const t = strings[many];
        let s = n === 1 ? one : many;
        if (Array.isArray(t) && t.length > 0) {
            s = Plural.pick(t, code, n);
        } else if (typeof t === "string") {
            const t1 = strings[one];
            s = n === 1 && typeof t1 === "string" ? t1 : t;
        }
        return s.replace("%1", n);
    }

    // Re-reads the language's file (after it was made).
    function reload() {
        if (code !== "en")
            fileView.reload();
    }

    FileView {
        id: fileView
        path: root.code === "en" ? "" : root.file
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
