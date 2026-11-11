import QtQuick
import qs.common
import qs.common.widgets

// Key "math": a minute of mental arithmetic. Problems come one after another and get harder every
// two solved ones (sums, tables, brackets, products of two-digit numbers). Type the answer: it is
// checked as soon as it has enough digits (Enter checks it early), a wrong one clears the line.
// Space skips a problem for a 3-second penalty. The clock starts with the first digit. R restarts,
// Esc closes.
Item {
    id: root

    required property bool revealed

    readonly property real total: 60
    readonly property real skipPenalty: 3
    readonly property int tiers: 9
    readonly property int maxDigits: 8

    property real timeLeft: total
    property bool started: false
    property bool over: false
    property int solved: 0
    property int mistakes: 0
    property int skipped: 0
    property int streak: 0
    property int bestStreak: 0
    property string problem: ""
    property string answer: ""
    property string typed: ""
    property real pop: 1
    property real flashA: 0
    property color flashColor: "#7ee787"
    property real shakeX: 0

    readonly property int level: Math.min(tiers - 1, Math.floor(solved / 2))
    readonly property real accuracy: solved + mistakes > 0 ? solved / (solved + mistakes) : 1
    readonly property string rank: solved < 5 ? Translation.tr("Warming up")
        : solved < 10 ? Translation.tr("Not bad")
        : solved < 15 ? Translation.tr("Quick head")
        : solved < 20 ? Translation.tr("Mental calculator")
        : Translation.tr("Human calculator")
    readonly property color timeColor: timeLeft > 20 ? "#7ee787" : (timeLeft > 10 ? "#ffb347" : "#ff6b6b")

    function between(a, b) {
        return a + Math.floor(Math.random() * (b - a + 1));
    }

    // [text, value] for the current difficulty tier
    function generate(tier) {
        let a, b, c, d;
        switch (tier) {
        case 0:
            a = between(2, 9); b = between(2, 9);
            return [`${a} + ${b}`, a + b];
        case 1:
            a = between(12, 49); b = between(11, 39);
            return Math.random() < 0.5 ? [`${a} + ${b}`, a + b] : [`${a + b} − ${b}`, a];
        case 2:
            a = between(3, 9); b = between(3, 9);
            return [`${a} × ${b}`, a * b];
        case 3:
            a = between(35, 99); b = between(25, 89);
            return Math.random() < 0.5 ? [`${a} + ${b}`, a + b] : [`${a + b} − ${b}`, a];
        case 4:
            a = between(11, 19); b = between(3, 9);
            return [`${a} × ${b}`, a * b];
        case 5:
            a = between(10, 60); b = between(3, 9); c = between(3, 9);
            return [`${a} + ${b} × ${c}`, a + b * c];
        case 6:
            a = between(3, 15); b = between(3, 15); c = between(3, 9);
            return [`(${a} + ${b}) × ${c}`, (a + b) * c];
        case 7:
            a = between(12, 25); b = between(12, 25);
            return [`${a} × ${b}`, a * b];
        default:
            a = between(4, 15); b = between(4, 15); c = between(4, 15); d = between(3, 12);
            return Math.random() < 0.5 ? [`${a} × ${b} + ${c} × ${d}`, a * b + c * d]
                : [`${a} × ${b} − ${c} × ${d % 3 + 1}`, a * b - c * (d % 3 + 1)];
        }
    }

    function nextProblem() {
        const p = generate(level);
        problem = p[0];
        answer = String(p[1]);
        typed = "";
        popAnim.restart();
    }

    function flash(good) {
        flashColor = good ? "#7ee787" : "#ff6b6b";
        flashAnim.restart();
    }

    function submit() {
        if (typed === "" || over)
            return;
        if (typed === answer) {
            solved++;
            streak++;
            bestStreak = Math.max(bestStreak, streak);
            flash(true);
            nextProblem();
        } else {
            mistakes++;
            streak = 0;
            flash(false);
            shakeAnim.restart();
            typed = "";
        }
    }

    function skip() {
        if (!started || over)
            return;
        skipped++;
        streak = 0;
        timeLeft = Math.max(0, timeLeft - skipPenalty);
        nextProblem();
    }

    function restart() {
        timeLeft = total;
        started = false;
        over = false;
        solved = 0;
        mistakes = 0;
        skipped = 0;
        streak = 0;
        bestStreak = 0;
        nextProblem();
    }

    function press(digit) {
        if (over || typed.length >= maxDigits)
            return;
        started = true;
        typed += String(digit);
        if (typed.length >= answer.length)
            submit();
    }

    Component.onCompleted: {
        forceActiveFocus();
        restart();
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace)
            return;
        if (event.key === Qt.Key_R) {
            restart();
        } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            press(event.key - Qt.Key_0);
        } else if (event.key === Qt.Key_Backspace) {
            typed = typed.slice(0, -1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            submit();
        } else if (event.key === Qt.Key_Space) {
            skip();
        }
    }

    FrameAnimation {
        running: root.revealed && root.started && !root.over
        onTriggered: {
            root.timeLeft = Math.max(0, root.timeLeft - frameTime);
            if (root.timeLeft <= 0)
                root.over = true;
        }
    }

    NumberAnimation { id: popAnim; target: root; property: "pop"; from: 0; to: 1; duration: 220; easing.type: Easing.OutBack }
    NumberAnimation { id: flashAnim; target: root; property: "flashA"; from: 0.28; to: 0; duration: 450 }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -18; duration: 40 }
        NumberAnimation { target: root; property: "shakeX"; to: 18; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -10; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 50 }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0d1224" }
            GradientStop { position: 1; color: "#1c1238" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.flashColor
        opacity: root.flashA
    }

    // The minute, draining
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        height: 10
        width: parent.width * root.timeLeft / root.total
        color: root.timeColor
    }

    StyledText {
        anchors.top: parent.top
        anchors.topMargin: 34
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(40, root.height / 12)
        font.bold: true
        color: root.timeColor
        text: root.timeLeft.toFixed(1)
    }

    // Difficulty: one pip per tier
    Row {
        anchors.top: parent.top
        anchors.topMargin: 34 + Math.max(40, root.height / 12) * 1.6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Repeater {
            model: root.tiers
            Rectangle {
                required property int index
                width: 26; height: 8; radius: 4
                color: index <= root.level ? "#ffd75e" : "#ffffff"
                opacity: index <= root.level ? 1 : 0.15
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: root.height / 20
        visible: !root.over

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(48, Math.min(root.height / 7, root.width / 14))
            font.bold: true
            color: "white"
            text: root.problem
            opacity: root.pop
            scale: 0.8 + 0.2 * root.pop
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(44, Math.min(root.height / 8, root.width / 16))
            color: "#ffd75e"
            text: "= " + root.typed + (root.typed === "" ? "_" : "")
            transform: Translate { x: root.shakeX }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 70
        visible: !root.over
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(18, root.height / 45)
        color: "white"
        opacity: 0.6
        horizontalAlignment: Text.AlignHCenter
        text: !root.started
            ? Translation.tr("A minute. Every two answers the problems get harder. Type a digit to start.")
            : Translation.tr("Solved: %1   Streak: %2   Space: skip (−3 s)").arg(root.solved).arg(root.streak)
    }

    // The result
    Column {
        anchors.centerIn: parent
        spacing: root.height / 40
        visible: root.over

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(80, root.height / 4)
            font.bold: true
            color: "#ffd75e"
            text: root.solved
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(28, root.height / 16)
            color: "white"
            text: root.rank
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(18, root.height / 40)
            color: "white"
            opacity: 0.7
            lineHeight: 1.5
            text: Translation.tr("Level reached: %1 of %2").arg(root.level + 1).arg(root.tiers) + "\n"
                + Translation.tr("Accuracy: %1%   Best streak: %2   Skipped: %3").arg(Math.round(root.accuracy * 100)).arg(root.bestStreak).arg(root.skipped) + "\n\n"
                + Translation.tr("R: again   Esc: close")
        }
    }
}
