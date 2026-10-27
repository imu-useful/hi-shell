.pragma library

// Material 3 Expressive shapes as radial outlines: each shape is r(θ) in 0..1,
// sampled at a fixed number of points so any two shapes can be morphed point by point.

const SAMPLES = 144;

// Rounded scallops: `n` lobes, valleys `depth` deep; higher `sharp` = narrower valleys.
function lobes(n, depth, sharp) {
    return t => 1 - depth * Math.pow(Math.abs(Math.sin(n * t / 2)), sharp);
}

// Union of `n` circles (radius `a`) centered `c` from the middle: round leaves.
function petals(n, c, a) {
    return t => {
        let r = 0;
        for (let k = 0; k < n; k++) {
            const phi = t - k * 2 * Math.PI / n;
            const d = c * Math.sin(phi);
            if (Math.abs(d) <= a)
                r = Math.max(r, c * Math.cos(phi) + Math.sqrt(a * a - d * d));
        }
        return r;
    };
}

// Superellipse (squircle); exponent 2 = circle, higher = squarer.
function squircle(e) {
    const f = t => Math.pow(Math.pow(Math.abs(Math.cos(t)), e) + Math.pow(Math.abs(Math.sin(t)), e), -1 / e);
    const max = f(Math.PI / 4);
    return t => f(t) / max;
}

// Rounded convex polygon with `n` corners, one pointing up. `round` (0 sharp .. 1 circle)
// blends the polygon's gauge (1 / radius) with the circle's, which keeps it convex.
function polygon(n, round) {
    const step = 2 * Math.PI / n;
    const apothem = Math.cos(Math.PI / n);
    return t => {
        // Angle from the middle of the nearest edge: |phi| <= PI / n (the corners are at the ends).
        const u = t + Math.PI / 2 - Math.PI / n;
        let phi = ((u % step) + step) % step;
        if (phi > step / 2)
            phi -= step;
        const r = apothem / Math.cos(phi);
        return 1 / ((1 - round) / r + round);
    };
}

// Ellipse: wide `a` (1), flat `b`.
function ellipse(b) {
    return t => 1 / Math.sqrt(Math.pow(Math.cos(t), 2) + Math.pow(Math.sin(t) / b, 2));
}

const radial = {
    circle: () => 1,
    square: squircle(5),
    // Scalloped "cookie" badges (M3 names: cookie4Sided ... cookie12Sided).
    cookie4: lobes(4, 0.16, 1.8),
    cookie6: lobes(6, 0.15, 2),
    cookie7: lobes(7, 0.14, 2),
    cookie9: lobes(9, 0.12, 2),
    cookie12: lobes(12, 0.09, 2),
    // Soft burst with many shallow waves (wallpaper frame, clock face).
    sunny: lobes(8, 0.12, 1.1),
    softBurst: lobes(10, 0.13, 1.2),
    // Round leaves meeting in narrow valleys.
    clover4: petals(4, 0.5, 0.5),
    clover8: petals(8, 0.64, 0.36),
    flower: lobes(8, 0.28, 2.5),
    // Irregular organic blob.
    blob: t => 0.9 + 0.055 * Math.sin(3 * t + 0.6) + 0.035 * Math.cos(5 * t - 0.4) + 0.02 * Math.sin(2 * t),
    // Ghost-ish arch: round top, wavy flat bottom.
    arch: t => {
        const s = Math.sin(t); // y grows downward
        if (s <= 0)
            return 1;
        const flat = 0.78 / s * (1 + 0.04 * Math.cos(6 * t));
        return Math.min(squircle(4)(t), flat);
    },
    pill: squircle(2.6),
    // Polygons with soft corners.
    triangle: polygon(3, 0.5),
    diamond: polygon(4, 0.45),
    pentagon: polygon(5, 0.45),
    hexagon: polygon(6, 0.42),
    oval: ellipse(0.74),
    // A circle cut flat below.
    dome: t => {
        const s = Math.sin(t);
        return s <= 0 ? 1 : Math.min(1, 0.55 / s);
    },
    // More bursts: finer rays, sharper rays, a star.
    verySunny: lobes(14, 0.1, 1),
    burst: lobes(10, 0.3, 0.55),
    boom: lobes(8, 0.24, 0.75),
    star: lobes(5, 0.5, 0.6),
    puffy: lobes(6, 0.2, 1.4),
    clover5: petals(5, 0.58, 0.42)
};

const names = Object.keys(radial);

// The wallpaper frames to choose from: [id, name]; "" = no frame.
const frames = [
    ["", "None"], ["circle", "Circle"], ["square", "Square"], ["pill", "Pill"], ["oval", "Oval"], ["dome", "Dome"],
    ["arch", "Arch"], ["triangle", "Triangle"], ["diamond", "Diamond"], ["pentagon", "Pentagon"], ["hexagon", "Hexagon"],
    ["sunny", "Sunny"], ["verySunny", "Very sunny"], ["softBurst", "Soft burst"], ["burst", "Burst"], ["boom", "Boom"],
    ["star", "Star"], ["cookie4", "Cookie 4"], ["cookie6", "Cookie 6"], ["cookie7", "Cookie 7"], ["cookie9", "Cookie"],
    ["cookie12", "Cookie 12"], ["clover4", "Clover"], ["clover5", "Clover 5"], ["clover8", "Clover 8"],
    ["flower", "Flower"], ["puffy", "Puffy"], ["blob", "Blob"]
];

// Normalized outline points (-1..1), starting at angle 0 and going clockwise in
// screen space. `rotation` is in degrees.
function points(name, rotation) {
    const f = radial[name] ?? radial.circle;
    const rot = (rotation ?? 0) * Math.PI / 180;
    const out = new Array(SAMPLES);
    let max = 0;
    for (let i = 0; i < SAMPLES; i++) {
        const t = i / SAMPLES * 2 * Math.PI;
        const r = f(t);
        max = Math.max(max, r);
        out[i] = [r * Math.cos(t + rot), r * Math.sin(t + rot)];
    }
    // Scale so the shape touches the bounds on at least one axis.
    let ext = 0;
    for (const p of out)
        ext = Math.max(ext, Math.abs(p[0]), Math.abs(p[1]));
    return out.map(p => [p[0] / ext, p[1] / ext]);
}

// Linear blend of two point lists (same length), progress 0..1.
function mix(a, b, progress) {
    const out = new Array(a.length);
    for (let i = 0; i < a.length; i++)
        out[i] = [a[i][0] + (b[i][0] - a[i][0]) * progress, a[i][1] + (b[i][1] - a[i][1]) * progress];
    return out;
}

// Point list scaled into a width × height box, closed, as Qt.point()s.
function toPath(pts, width, height) {
    const out = pts.map(p => Qt.point((p[0] + 1) * width / 2, (p[1] + 1) * height / 2));
    out.push(out[0]);
    return out;
}
