#version 440

// An airy, water-like scene: a slowly flowing pastel gradient with soft caustic lines, rings of
// ripples, rising layers of water, and glossy drops that bend the background behind them.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float ripples;
    float waves;
    vec4 c0; vec4 c1; vec4 c2;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3; vec4 b4; vec4 b5; vec4 b6; vec4 b7; // x, y, radius (px)
};

float unit; // the shorter side, in px

// P: centered, in units of the shorter side (y grows downwards)
vec3 background(vec2 P) {
    vec2 q = P + 0.18 * vec2(sin(P.y * 3.0 + time * 0.45), cos(P.x * 3.2 - time * 0.38));
    float f = 0.5 + 0.5 * sin(q.x * 2.3 + sin(q.y * 2.9 + time * 0.3) + time * 0.2);
    float g = 0.5 + 0.5 * sin(q.y * 1.9 + sin(q.x * 2.5 - time * 0.27) - time * 0.15);
    vec3 col = mix(mix(c0.rgb, c1.rgb, f), c2.rgb, g * 0.65);
    float caustic = pow(1.0 - abs(sin(q.x * 7.0 + sin(q.y * 5.0 + time * 0.6) * 1.3 + time * 0.5)), 14.0);
    return col + 0.07 * caustic;
}

vec3 drop(vec3 col, vec2 p, vec4 b, vec3 tint) {
    float r = b.z;
    if (r < 1.0)
        return col;
    vec2 d2 = p - b.xy;
    float dist = length(d2);
    // The soft shadow it throws, below and to the right
    float sh = smoothstep(r * 1.6, r * 0.7, length(p - b.xy - vec2(r * 0.2, r * 0.38)));
    col *= 1.0 - 0.13 * sh * step(r, dist);
    if (dist > r + 1.5)
        return col;

    vec2 n2 = d2 / r;
    float z = sqrt(max(0.0, 1.0 - dot(n2, n2)));
    vec3 N = vec3(n2, z);
    // What it shows is the background bent towards the rim, like looking through a lens
    vec2 seen = p - n2 * r * 0.45 * (1.0 - 0.5 * z);
    vec3 behind = background((seen - 0.5 * res) / unit);
    vec3 L = normalize(vec3(-0.5, -0.55, 0.65));
    float diff = max(dot(N, L), 0.0);
    float spec = pow(max(dot(reflect(-L, N), vec3(0.0, 0.0, 1.0)), 0.0), 36.0);
    float rim = pow(1.0 - z, 2.2);
    vec3 body = mix(behind, tint, 0.3 + 0.2 * rim) * (0.88 + 0.28 * diff);
    body += vec3(1.0) * (spec * 0.9 + rim * 0.3);
    body += vec3(1.0) * 0.3 * pow(max(dot(N, normalize(vec3(0.5, 0.6, 0.62))), 0.0), 24.0);
    return mix(col, body, smoothstep(r + 1.0, r - 1.0, dist));
}

void main() {
    unit = min(res.x, res.y);
    vec2 p = qt_TexCoord0 * res;
    vec2 P = (p - 0.5 * res) / unit;

    vec3 col = background(P);

    // Rings leaving a point a little above the middle: a bright crest with a soft trough behind it
    for (int k = 0; k < 3; k++) {
        float phase = fract(time / 2.8 + float(k) / 3.0);
        float d = length(P - vec2(0.0, -0.08));
        float crest = exp(-pow((d - phase * 0.95) / 0.035, 2.0));
        float trough = exp(-pow((d - phase * 0.95 + 0.06) / 0.06, 2.0));
        col += ripples * (1.0 - phase) * (0.3 * crest - 0.07 * trough);
    }

    // Three layers of water rising from the bottom, each with a bright line along its top
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float top = mix(1.0, 0.1 + 0.07 * fi, waves) + 0.03 * waves * sin(P.x * (3.0 + fi) + time * (0.8 + 0.3 * fi) + fi * 2.0);
        float m = smoothstep(top - 0.003, top + 0.003, P.y);
        vec3 water = mix(c1.rgb, c2.rgb, 0.3 * fi) * (0.97 - 0.06 * fi);
        col = mix(col, water, m * 0.42);
        col += 0.45 * waves * exp(-pow((P.y - top) / 0.006, 2.0));
    }

    col = drop(col, p, b0, clamp(c0.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b1, clamp(c1.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b2, clamp(c2.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b3, clamp(c0.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b4, clamp(c1.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b5, clamp(c2.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b6, clamp(c0.rgb * 0.8, 0.0, 1.0));
    col = drop(col, p, b7, clamp(c1.rgb * 0.8, 0.0, 1.0));

    col *= 1.0 - 0.1 * dot(P, P);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
