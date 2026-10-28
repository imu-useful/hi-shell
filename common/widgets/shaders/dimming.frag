#version 440
// The region selector's dimming: the screen goes dark except a rounded rectangle (the
// selection), which gets an outline. Like hyprquickshot's dimming shader, with an
// anti-aliased edge and a colored outline.
// Rebuild after editing: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o dimming.frag.qsb dimming.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 selectionRect; // x, y, width, height in px
    vec4 outlineColor;
    vec2 screenSize;
    float dimOpacity;
    float borderRadius;
    float outlineThickness;
};

float roundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 halfSize = max(selectionRect.zw, vec2(0.0)) / 2.0;
    vec2 p = qt_TexCoord0 * screenSize - (selectionRect.xy + halfSize);
    float d = roundedBox(p, halfSize, min(borderRadius, min(halfSize.x, halfSize.y)));

    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    float ring = smoothstep(-0.5, 0.5, d) * (1.0 - smoothstep(outlineThickness - 0.5, outlineThickness + 0.5, d));
    // No outline for a selection that's still a point.
    ring *= smoothstep(0.0, 3.0, min(selectionRect.z, selectionRect.w));

    float ringAlpha = ring * outlineColor.a;
    vec4 dim = vec4(0.0, 0.0, 0.0, dimOpacity * (1.0 - inside));
    vec4 outline = vec4(outlineColor.rgb * ringAlpha, ringAlpha);
    fragColor = (outline + dim * (1.0 - ringAlpha)) * qt_Opacity;
}
