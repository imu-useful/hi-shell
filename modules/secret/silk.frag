#version 440

// The keynote finale: ribbons of silky light drifting over a near-black stage, in three colors
// (the wallpaper's). Each ribbon is a soft band along a slow wave, shaded by its slope so it reads
// as folded fabric, with a thin bright edge. `kick` (0..1, on the beat) lifts the light a little.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float kick;
    vec4 c0;
    vec4 c1;
    vec4 c2;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The center line of ribbon i at x, and its slope
float wave(float x, float i, float t) {
    return 0.22 * sin(x * 1.1 + t * 0.23 + i * 1.7)
         + 0.09 * sin(x * 2.3 - t * 0.31 + i * 2.9)
         + 0.04 * sin(x * 4.1 + t * 0.47 + i * 0.6)
         + (i - 2.5) * 0.055;
}

void main() {
    vec2 frag = qt_TexCoord0 * res;
    float unit = min(res.x, res.y);
    vec2 P = (frag - res * 0.5) / unit;
    P.y = -P.y;
    // The whole sheet leans a little, like a stage backdrop
    P = mat2(0.96, -0.28, 0.28, 0.96) * P;

    vec3 col = vec3(0.012, 0.012, 0.02);
    for (int k = 0; k < 6; k++) {
        float i = float(k);
        float t = time;
        float y = wave(P.x, i, t);
        float slope = (wave(P.x + 0.01, i, t) - y) / 0.01;
        float d = P.y - y;
        float width = 0.035 + 0.025 * sin(P.x * 1.7 + t * 0.4 + i * 1.3) + 0.012 * i;
        float band = exp(-d * d / (width * width));
        float edge = exp(-abs(d - width * 0.6) * 90.0) * 0.6;
        // Folds: the light rises and falls with the ribbon's slope
        float fold = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(slope * 2.2 + P.x * 1.4 - t * 0.5 + i), 2.0);
        vec3 tint = mix(mix(c0.rgb, c1.rgb, 0.5 + 0.5 * sin(P.x * 0.9 + i * 1.1 + t * 0.15)), c2.rgb,
                        0.5 + 0.5 * sin(i * 2.3 - P.x * 0.6));
        col += tint * (band * fold * 0.4 + edge * band * 1.2) * (0.55 + 0.45 * sin(i * 1.9 + t * 0.2));
    }

    col *= 1.0 + 0.3 * kick;
    col = 1.0 - exp(-col * 1.4);
    vec2 uv = qt_TexCoord0 - 0.5;
    col *= 1.0 - dot(uv, uv) * 1.6;
    col += (hash(frag + fract(time) * 91.0) - 0.5) * 0.018;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
