#version 440

// A dot matrix: `grid` is a tiny texture with one pixel per cell. R is the brightness of the grid
// dot (its size follows it), B the size of a big white dot (the text), G the size of a red one.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float cols;
    float rows;
};

layout(binding = 1) uniform sampler2D grid;

void main() {
    float cs = res.x / cols;
    vec2 p = qt_TexCoord0 * res;
    vec2 cell = floor(p / cs);
    vec4 d = texture(grid, (cell + 0.5) / vec2(cols, rows));
    float dist = length(p / cs - cell - 0.5);
    float aa = 1.3 / cs;

    float lv = d.r;
    float rw = 0.07 + 0.33 * lv;
    float aw = (0.14 + 0.86 * lv) * smoothstep(rw + aa, rw - aa, dist) * step(0.004, lv);
    float rt = 0.4 * d.b * 1.5;
    float at = smoothstep(rt + aa, rt - aa, dist) * step(0.01, d.b);
    float rr = min(0.47, 0.4 * d.g * 2.0 * 0.8);
    float ar = smoothstep(rr + aa, rr - aa, dist) * step(0.01, d.g);

    vec3 col = vec3(max(aw, at));
    col = mix(col, vec3(0.843, 0.098, 0.098), ar);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
