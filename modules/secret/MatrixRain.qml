import QtQuick
import qs.common

// Key "matrix": falling green characters.
Canvas {
    id: root

    required property bool revealed
    readonly property int cell: 20
    readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ0123456789hi"
    property var drops: []

    onWidthChanged: drops = []

    Timer {
        interval: 55
        running: root.revealed
        repeat: true
        onTriggered: root.requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d");
        const cols = Math.ceil(width / cell);
        if (drops.length !== cols)
            drops = Array.from({ length: cols }, () => -Math.random() * height / cell);
        // Fade the previous frame instead of clearing it: that leaves the trails
        ctx.fillStyle = "rgba(0, 0, 0, 0.12)";
        ctx.fillRect(0, 0, width, height);
        ctx.font = `${cell}px ${Appearance.font.mono}`;
        for (let i = 0; i < cols; i++) {
            const g = glyphs[Math.floor(Math.random() * glyphs.length)];
            ctx.fillStyle = "#c8ffd0";
            ctx.fillText(g, i * cell, drops[i] * cell);
            ctx.fillStyle = "#1fdc4a";
            ctx.fillText(glyphs[Math.floor(Math.random() * glyphs.length)], i * cell, (drops[i] - 1) * cell);
            if (drops[i] * cell > height && Math.random() > 0.975)
                drops[i] = 0;
            drops[i] += 1;
        }
    }
}
