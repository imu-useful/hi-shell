#version 440

// A bright glossy scene: blue sky with a sun, light rays and drifting clouds, green hills in layers,
// and soap bubbles with a rainbow skin that bend what is behind them.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3; vec4 b4; vec4 b5; vec4 b6; vec4 b7; // x, y, radius (px)
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// q: x from 0 to the aspect ratio, y from 0 (top) to 1
vec3 scene(vec2 q) {
    float aspect = res.x / res.y;
    float y = q.y;
    vec3 col = mix(vec3(0.03, 0.32, 0.82), vec3(0.42, 0.76, 1.0), smoothstep(0.0, 0.65, y));
    col = mix(col, vec3(0.86, 0.96, 1.0), smoothstep(0.45, 0.8, y));

    vec2 sun = vec2(aspect * 0.8, 0.2);
    float d = length(q - sun);
    col += vec3(1.0, 0.96, 0.82) * (exp(-d * 3.0) * 0.5 + exp(-d * 16.0) * 0.9);
    float ang = atan(q.y - sun.y, q.x - sun.x);
    col += vec3(1.0, 0.95, 0.8) * pow(max(0.0, cos(ang * 9.0 + time * 0.15)), 10.0) * exp(-d * 2.2) * 0.16;
    vec2 ctr = vec2(aspect * 0.5, 0.5);
    for (int k = 1; k < 4; k++) {
        vec2 pos = sun + (ctr - sun) * float(k) * 0.55;
        float dd = length(q - pos), rr = 0.03 * float(k);
        col += vec3(0.5 + 0.1 * float(k), 0.8, 1.0) * exp(-pow((dd - rr) / 0.012, 2.0)) * 0.1;
    }

    float cl = smoothstep(0.5, 0.8, fbm(q * vec2(1.5, 3.0) + vec2(time * 0.02, 0.0)));
    col = mix(col, vec3(1.0), cl * 0.7 * smoothstep(0.75, 0.15, y));

    // Hills, the far ones pale with haze, the near ones deep green
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float x = q.x + time * 0.012 * (1.0 + fi);
        float hy = 0.66 + 0.08 * fi + 0.045 * sin(x * (2.0 + fi) + 1.7 * fi) + 0.015 * sin(x * (6.0 + fi * 2.0));
        if (y > hy) {
            vec3 g = mix(vec3(0.58, 0.88, 0.36), vec3(0.08, 0.46, 0.18), clamp((y - hy) * 3.0 + 0.18 * fi, 0.0, 1.0));
            col = mix(g, vec3(0.72, 0.9, 0.96), 0.42 * (1.0 - fi / 2.0));
        }
        col += vec3(0.9, 1.0, 0.6) * exp(-pow((y - hy) / 0.004, 2.0)) * 0.3;
    }
    return col;
}

vec3 bubble(vec3 col, vec2 p, vec4 b) {
    float r = b.z;
    if (r < 1.0)
        return col;
    vec2 d2 = p - b.xy;
    float dist = length(d2);
    if (dist > r + 1.5)
        return col;
    vec2 n2 = d2 / r;
    float z = sqrt(max(0.0, 1.0 - dot(n2, n2)));
    vec3 N = vec3(n2, z);
    vec3 behind = scene((p - n2 * r * 0.35 * (1.0 - 0.5 * z)) / res.y);
    float fres = pow(1.0 - z, 2.0);
    vec3 irid = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + fres * 1.2 + time * 0.08 + b.x * 0.002));
    vec3 L = normalize(vec3(-0.5, -0.6, 0.65));
    float spec = pow(max(dot(reflect(-L, N), vec3(0.0, 0.0, 1.0)), 0.0), 40.0);
    float spec2 = pow(max(dot(N, normalize(vec3(0.5, 0.55, 0.62))), 0.0), 30.0);
    vec3 body = behind * (1.0 + 0.15 * max(dot(N, L), 0.0)) + irid * fres * 0.75 + vec3(1.0) * (spec * 1.1 + spec2 * 0.35);
    return mix(col, body, smoothstep(r + 1.0, r - 1.0, dist));
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec3 col = scene(p / res.y);
    col = bubble(col, p, b0);
    col = bubble(col, p, b1);
    col = bubble(col, p, b2);
    col = bubble(col, p, b3);
    col = bubble(col, p, b4);
    col = bubble(col, p, b5);
    col = bubble(col, p, b6);
    col = bubble(col, p, b7);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
