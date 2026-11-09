#version 440

// Liquid glass: up to eight metaballs merge into one pane of glass over `src`. Inside it the
// picture is bent towards the rim (refraction), split into colors a little (dispersion), softened,
// and lit: a bright edge on the side facing the light, a cool glow on the far side, a highlight.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3; vec4 b4; vec4 b5; vec4 b6; vec4 b7; // x, y, radius (px), unused
};

layout(binding = 1) uniform sampler2D src;

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float field(vec2 p, float k) {
    float d = length(p - b0.xy) - b0.z;
    d = smin(d, length(p - b1.xy) - b1.z, k);
    d = smin(d, length(p - b2.xy) - b2.z, k);
    d = smin(d, length(p - b3.xy) - b3.z, k);
    d = smin(d, length(p - b4.xy) - b4.z, k);
    d = smin(d, length(p - b5.xy) - b5.z, k);
    d = smin(d, length(p - b6.xy) - b6.z, k);
    d = smin(d, length(p - b7.xy) - b7.z, k);
    return d;
}

void main() {
    float u = min(res.x, res.y);
    vec2 p = qt_TexCoord0 * res;
    float k = 0.11 * u;
    float d = field(p, k);
    vec3 bg = texture(src, qt_TexCoord0).rgb;

    // Soft shadow the glass casts on what is around it
    float shadow = smoothstep(0.05 * u, 0.0, d) * step(0.0, d);
    bg *= 1.0 - 0.3 * shadow * shadow;

    if (d > 1.5) {
        fragColor = vec4(bg, 1.0) * qt_Opacity;
        return;
    }

    float e = 1.5;
    vec2 grad = vec2(field(p + vec2(e, 0.0), k) - field(p - vec2(e, 0.0), k),
                     field(p + vec2(0.0, e), k) - field(p - vec2(0.0, e), k));
    vec2 n = normalize(grad + 1e-5); // points out of the glass

    float depth = clamp(-d / (0.085 * u), 0.0, 1.0); // 0 at the rim, 1 deep inside
    float edge = 1.0 - depth;
    float bend = edge * edge * 0.09 * u; // px the picture is pulled by, strongest at the rim
    vec2 off = -n * bend / res;

    // Dispersion: red, green and blue look through slightly different amounts of glass.
    // A few taps in a ring soften it (more towards the middle: frosted, not clear).
    float blur = (1.2 + 3.0 * depth) / u;
    vec3 col = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.0471976;
        vec2 t = vec2(cos(a), sin(a)) * blur;
        col.r += texture(src, qt_TexCoord0 + off * 1.00 + t).r;
        col.g += texture(src, qt_TexCoord0 + off * 1.07 + t).g;
        col.b += texture(src, qt_TexCoord0 + off * 1.14 + t).b;
    }
    col /= 6.0;

    // Light from the upper left
    float facing = dot(n, normalize(vec2(-0.55, -0.83)));
    float rim = pow(edge, 2.3);
    col = col * 1.05 + 0.05;
    col += vec3(1.0) * rim * (0.2 + 0.8 * max(facing, 0.0)) * 0.9;
    col += vec3(0.55, 0.72, 1.0) * pow(edge, 4.0) * max(-facing, 0.0) * 0.55;
    col += vec3(1.0) * pow(max(facing, 0.0), 10.0) * pow(edge, 1.3) * 0.6;
    // A thin bright line right at the surface
    col += vec3(1.0) * smoothstep(2.5, 0.0, abs(d + 1.2)) * (0.3 + 0.4 * max(facing, 0.0));

    float inside = smoothstep(1.2, -1.2, d);
    fragColor = vec4(mix(bg, col, inside), 1.0) * qt_Opacity;
}
