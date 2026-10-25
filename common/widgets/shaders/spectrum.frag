#version 440
// Audio spectrum bars with rounded caps, drawn in one pass (common/widgets/Spectrum.qml).
// Rebuild after editing: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o spectrum.frag.qsb spectrum.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
    vec2 size;      // item size in px
    float bars;
    float gap;      // px between bars
    float minLength;
    float orient;   // 0: grow up from the bottom, 1: centered (bars side by side), 2: centered, stacked vertically
    vec4 l0; vec4 l1; vec4 l2; vec4 l3; vec4 l4; vec4 l5; vec4 l6; vec4 l7;
    vec4 l8; vec4 l9; vec4 l10; vec4 l11; vec4 l12; vec4 l13; vec4 l14; vec4 l15;
};

void main() {
    vec4 levels[16] = vec4[](l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15);
    vec2 p = qt_TexCoord0 * size;
    bool stacked = orient > 1.5;

    float along = stacked ? p.y : p.x;          // across the bars
    float across = stacked ? p.x : p.y;         // along a bar
    float extent = stacked ? size.y : size.x;
    float cross = stacked ? size.x : size.y;

    float slot = extent / bars;
    int i = int(min(floor(along / slot), bars - 1.0));
    float local = along - float(i) * slot;
    float thickness = max(1.0, slot - gap);

    float level = levels[i / 4][i % 4];
    float len = clamp(level * cross, minLength, cross);
    float start = orient < 0.5 ? cross - len : (cross - len) * 0.5;

    // Distance to a capsule: a segment along the bar, inflated by the radius.
    float r = min(thickness, len) * 0.5;
    float centre = thickness * 0.5;
    float y = clamp(across, start + r, start + len - r);
    float d = length(vec2(local - centre, across - y)) - r;
    float alpha = clamp(0.5 - d, 0.0, 1.0);

    fragColor = vec4(color.rgb * color.a, color.a) * alpha * qt_Opacity;
}
