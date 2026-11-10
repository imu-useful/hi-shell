#version 440

// A neon trip in four scenes that melt into each other: a warp tunnel of glowing rings, a spinning
// kaleidoscope fractal, liquid iridescent chrome, and a synthwave sun over an endless grid.
// `mixw` holds each scene's weight (only those above zero are drawn), `beat` is a 0..1 pulse that
// kicks the zoom, the glow and the color split, `warp` swirls the picture while scenes change.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float beat;
    float hue;
    float warp;
    vec4 mixw; // tunnel, kaleidoscope, liquid, synthwave
};

const float TAU = 6.2831853;

// A saturated neon palette around `hue` (squaring keeps the mixes from going muddy)
vec3 pal(float t) {
    vec3 c = 0.5 + 0.5 * cos(TAU * (t + hue - vec3(0.0, 0.33, 0.67)));
    return c * c * 1.3;
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// P: centered, in units of the shorter side, y up
vec3 tunnel(vec2 p) {
    float r = max(length(p), 1e-3);
    float a = atan(p.y, p.x);
    float z = 0.9 / r + time * 2.6;
    // Twelve spokes that twist with depth into spirals
    float ang = a / TAU * 12.0 + z * 0.18 + time * 0.2;
    float dz = abs(fract(z) - 0.5);
    float da = abs(fract(ang) - 0.5);
    vec3 tile = pal(floor(z) * 0.13 + floor(ang) * 0.04) * 0.18 * (0.5 + 0.5 * sin(floor(z) * 1.7 + floor(ang) * 2.3 + time * 3.0));
    vec3 col = tile
             + pal(floor(z) * 0.11 + time * 0.05) * 0.03 / (dz + 0.012)
             + pal(floor(ang) * 0.05 + time * 0.07 + 0.5) * 0.015 / (da + 0.02);
    col *= smoothstep(0.015, 0.22, r);
    col += pal(time * 0.1 + 0.2) * 0.02 / (r + 0.01);
    return col;
}

vec3 kaleido(vec2 p) {
    p *= rot(time * 0.12);
    float r = length(p);
    float seg = TAU / 10.0;
    float a = abs(mod(atan(p.y, p.x), seg) - seg * 0.5);
    p = r * vec2(cos(a), sin(a));
    vec2 z = p * (1.4 + 0.25 * sin(time * 0.2));
    vec2 c = vec2(0.82 + 0.08 * sin(time * 0.31), 0.58 + 0.08 * cos(time * 0.23));
    vec3 col = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        z = abs(z) / max(dot(z, z), 2e-3) - c;
        float d = abs(length(z) - 0.9);
        col += pal(float(i) * 0.09 + r * 0.4 - time * 0.06) * exp(-d * 22.0);
    }
    return col * 0.45 * (0.7 + 0.6 * pow(0.5 + 0.5 * sin(r * 12.0 - time * 3.0), 3.0));
}

vec3 liquid(vec2 p) {
    vec2 q = p * 1.8;
    for (int i = 1; i < 6; i++) {
        float fi = float(i);
        q += 0.55 / fi * vec2(sin(q.y * 1.6 * fi + time * 0.5 + fi), cos(q.x * 1.4 * fi - time * 0.42 + fi * 1.3));
    }
    float f = sin(q.x * 1.7) + sin(q.y * 1.9);
    // A narrow slice of the palette, so the chrome stays in neighbouring hues
    vec3 col = pal(f * 0.05 + length(q) * 0.015 + 0.08 * sin(time * 0.2)) * max(0.0, 0.3 + 0.3 * f);
    float shine = pow(max(0.0, sin(f * 3.0 + time * 1.2)), 14.0);
    col += vec3(1.0, 0.95, 1.0) * shine * 0.7;
    col += pal(f * 0.3 + 0.5) * pow(max(0.0, cos(f * 2.0 - time)), 30.0) * 0.5;
    return col;
}

vec3 synthwave(vec2 p) {
    float horizon = -0.08;
    vec3 col;
    if (p.y > horizon) {
        float h = p.y - horizon;
        col = mix(vec3(0.6, 0.05, 0.4), vec3(0.03, 0.0, 0.1), smoothstep(0.0, 0.45, h));
        // Stars
        vec2 cell = floor(p * 40.0);
        float s = hash(cell);
        vec2 at = fract(p * 40.0) - 0.5 - 0.3 * (vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5);
        float star = step(0.93, s) * 0.012 / (dot(at, at) + 0.012);
        col += vec3(0.9, 0.9, 1.0) * star * (0.4 + 0.6 * sin(time * 3.0 + s * 50.0)) * smoothstep(0.1, 0.35, h);
        // The sun with its cut stripes
        vec2 sp = p - vec2(0.0, 0.13);
        float sd = length(sp);
        float stripe = 1.0;
        if (sp.y < 0.0) {
            float k = -sp.y / 0.24;
            stripe = step(0.1 + k * 0.6, fract(sp.y * 14.0 + time * 0.6));
        }
        vec3 sun = mix(vec3(1.0, 0.05, 0.45), vec3(1.0, 0.85, 0.1), smoothstep(-0.2, 0.2, sp.y)) * 1.4;
        col = mix(col, sun, smoothstep(0.24, 0.236, sd) * stripe);
        col += vec3(1.0, 0.2, 0.5) * 0.03 / (max(sd - 0.24, 0.0) + 0.03) * 0.3;
    } else {
        float d = horizon - p.y;
        float z = 0.25 / d;
        vec2 g = vec2(p.x * z * 2.0, z * 2.0 + time * 2.2);
        vec2 fw = fwidth(g);
        vec2 line = abs(fract(g) - 0.5) / fw;
        float grid = 1.0 - clamp(min(line.x, line.y) - 0.5, 0.0, 1.0);
        float glow = 0.02 / (min(abs(fract(g.x) - 0.5), abs(fract(g.y) - 0.5)) + 0.02);
        vec3 neon = mix(vec3(0.1, 0.9, 1.0), vec3(1.0, 0.2, 0.9), 0.5 + 0.5 * sin(g.y * 0.1 + time));
        float fade = exp(-z * 0.12);
        col = vec3(0.04, 0.0, 0.08) + neon * (grid + glow * 0.25) * fade;
        col += vec3(1.0, 0.3, 0.6) * exp(-d * 18.0) * 0.6;
    }
    return col;
}

vec3 scene(vec2 p) {
    vec3 col = vec3(0.0);
    if (mixw.x > 0.001) col += mixw.x * tunnel(p);
    if (mixw.y > 0.001) col += mixw.y * kaleido(p);
    if (mixw.z > 0.001) col += mixw.z * liquid(p);
    if (mixw.w > 0.001) col += mixw.w * synthwave(p);
    return col;
}

void main() {
    vec2 frag = qt_TexCoord0 * res;
    float unit = min(res.x, res.y);
    vec2 P = (frag - res * 0.5) / unit;
    P.y = -P.y;

    // The beat kicks the zoom; a scene change swirls everything around the center
    P *= 1.0 - 0.05 * beat;
    float r = length(P);
    P *= rot(warp * 3.0 * exp(-r * 1.5));

    vec3 col = scene(P);
    // Color split: red from a slightly bigger picture, the rest from the true one
    vec3 shifted = scene(P * (1.0 - 0.01 - 0.02 * beat));
    col = vec3(shifted.r, col.g, mix(col.b, shifted.b, 0.35));

    col *= 1.0 + 0.35 * beat;
    col += pal(time * 0.2) * warp * 0.5;
    col = 1.0 - exp(-col * 1.8);

    // Scanlines, grain, vignette
    col *= 0.94 + 0.06 * sin(frag.y * 3.14159);
    col += (hash(frag + fract(time) * 100.0) - 0.5) * 0.025;
    vec2 uv = qt_TexCoord0 - 0.5;
    col *= 1.0 - dot(uv, uv) * 0.9;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
