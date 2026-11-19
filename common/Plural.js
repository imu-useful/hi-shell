.pragma library

// Which form of a counted phrase a language uses for n: 0 is "one", then the next ones.
//   ru, uk: 1 / 2-4 / 5-20 (three forms)     de, en, es, pt and the rest: 1 / other (two)
//   zh, ja, ko: one form for every number
function index(code, n) {
    const a = Math.abs(n);
    if (code === "ru" || code === "uk") {
        const m10 = a % 10, m100 = a % 100;
        return m10 === 1 && m100 !== 11 ? 0 : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? 1 : 2;
    }
    if (code === "zh" || code === "ja" || code === "ko")
        return 0;
    return a === 1 ? 0 : 1;
}

// The form of a translation's list `forms` for n (a shorter list than the language needs uses its last form).
function pick(forms, code, n) {
    return forms[Math.min(index(code, n), forms.length - 1)];
}
