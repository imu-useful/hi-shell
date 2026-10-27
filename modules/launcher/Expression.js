.pragma library

// Does the launcher text read as a calculation ("12*(3+4)", "2^10 / 4"), as opposed to an
// app name ("7-zip", "p7zip")? Only digits, . + - * / ^ × ÷ % and parentheses count, the
// expression has to be well formed (qalc would quietly make sense of "2+") and have at
// least one operator between two operands. A closing = is allowed.
// The expression without a closing "=" ("10+5=" asks for the answer, like on a calculator).
function strip(text) {
    return text.replace(/\s*=+\s*$/, "");
}

function isMath(text) {
    const s = strip(text).replace(/\s+/g, "");
    if (!/^[\d.+\-*/^×÷%()]+$/.test(s) || !/\d/.test(s))
        return false;
    const tokens = s.match(/\d+(?:\.\d+)?|\.\d+|[+\-*/^×÷%()]/g) ?? [];
    if (tokens.join("") !== s)
        return false;
    let i = 0, binary = false;

    function expr() {
        if (!term())
            return false;
        while (tokens[i] === "+" || tokens[i] === "-") {
            i++;
            binary = true;
            if (!term())
                return false;
        }
        return true;
    }
    function term() {
        if (!power())
            return false;
        while (["*", "/", "×", "÷"].includes(tokens[i])) {
            i++;
            binary = true;
            if (!power())
                return false;
        }
        return true;
    }
    function power() {
        if (!unary())
            return false;
        if (tokens[i] === "^") {
            i++;
            binary = true;
            return power();
        }
        return true;
    }
    function unary() {
        if (tokens[i] === "+" || tokens[i] === "-") {
            i++;
            return unary();
        }
        return atom();
    }
    function atom() {
        const t = tokens[i];
        if (t === "(") {
            i++;
            if (!expr() || tokens[i] !== ")")
                return false;
            i++;
            return true;
        }
        if (t !== undefined && /^[\d.]/.test(t)) {
            i++;
            if (tokens[i] === "%")
                i++;
            return true;
        }
        return false;
    }

    return expr() && i === tokens.length && binary;
}
