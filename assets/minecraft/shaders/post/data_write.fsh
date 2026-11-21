#version 330
#extension GL_ARB_separate_shader_objects : require

uniform sampler2D PrevDataSampler;
uniform sampler2D MainSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    // Marker pixel written by particle.vsh at framebuffer (0,0): color (0.85, 0.85, id, 1.0)
    vec4 markerPixel = texelFetch(MainSampler, ivec2(0, 0), 0);
    ivec4 snapped = ivec4(round(markerPixel * 20.0));

    if (snapped.r == 17 && snapped.g == 17 && snapped.a == 20) {
        fragColor = vec4(snapped) / 20.0;
        return;
    }

    // No marker this frame: keep the stored value
    fragColor = texelFetch(PrevDataSampler, ivec2(0, 0), 0);
}