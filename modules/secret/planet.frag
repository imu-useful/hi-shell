#version 440

// A planet seen from the dark: banded surface turning slowly, lit from the upper left, with a thin
// glowing atmosphere. The item is 1.35 times the planet's diameter so the glow has room.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 colA;
    vec4 colB;
    vec4 glow;
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

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0 * 1.35;
    float r = length(p);
    vec3 L = normalize(vec3(-0.6, -0.5, 0.7));

    if (r > 1.0) {
        // The glow fades to nothing before the edge of the item, or the item shows as a box
        float g = exp(-(r - 1.0) * 7.0) * smoothstep(1.35, 1.08, r);
        float lit = 0.3 + 0.7 * max(dot(normalize(p), normalize(L.xy)), 0.0);
        float a = g * 0.8 * lit;
        fragColor = vec4(glow.rgb * a, a) * qt_Opacity;
        return;
    }

    float z = sqrt(1.0 - r * r);
    vec3 N = vec3(p, z);
    float lon = atan(N.x, N.z) + time * 0.15;
    float lat = asin(clamp(N.y, -1.0, 1.0));
    float n = fbm(vec2(lon * 3.0, lat * 6.0));
    float bands = 0.5 + 0.5 * sin(lat * 11.0 + n * 4.5);
    vec3 col = mix(colA.rgb, colB.rgb, clamp(bands * 0.6 + n * 0.55, 0.0, 1.0));

    float d = dot(N, L);
    col *= 0.1 + 1.0 * smoothstep(-0.05, 0.4, d) * (0.4 + 0.6 * max(d, 0.0));
    float fres = pow(1.0 - z, 3.0);
    col += glow.rgb * fres * (0.2 + 0.8 * max(d + 0.3, 0.0));

    float aa = smoothstep(1.0, 0.985, r);
    fragColor = vec4(col, 1.0) * aa * qt_Opacity;
}
