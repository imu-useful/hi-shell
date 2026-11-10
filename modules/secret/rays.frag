#version 440

// God rays for the keynote finale: soft beams of light fanning out from a point, slowly turning,
// flaring with `kick`. Two layers of beams at different speeds keep it from looking regular.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    vec2 center; // in pixels
    float time;
    float kick;
    vec4 tint;
    vec4 tint2;
};

void main() {
    vec2 frag = qt_TexCoord0 * res;
    vec2 d = (frag - center) / min(res.x, res.y);
    float r = length(d);
    float a = atan(d.y, d.x);

    float b1 = pow(0.5 + 0.5 * sin(a * 9.0 + time * 0.35), 6.0);
    float b2 = pow(0.5 + 0.5 * sin(a * 14.0 - time * 0.22 + 1.3), 10.0);
    float beams = b1 * 0.7 + b2 * 0.5;
    // Bright near the source, fading out, and no hard point in the middle
    float fall = exp(-r * 1.6) * smoothstep(0.0, 0.12, r);
    vec3 col = mix(tint.rgb, tint2.rgb, 0.5 + 0.5 * sin(a * 2.0 + time * 0.2)) * beams * fall;
    col *= 0.55 + 0.6 * kick;

    fragColor = vec4(col, 0.0) * qt_Opacity;
}
