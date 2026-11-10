#version 440

// A soft round blob of light: `tint` fading out from the middle to nothing at the edges.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
};

void main() {
    float d = length(qt_TexCoord0 * 2.0 - 1.0);
    float a = 1.0 - smoothstep(0.0, 1.0, d);
    a *= a;
    fragColor = vec4(tint.rgb, 1.0) * a * qt_Opacity;
}
