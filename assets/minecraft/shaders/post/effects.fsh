#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>
#include <minecraft:thunderstorm_particle_effects.glsl>

uniform sampler2D InSampler;
uniform sampler2D DataSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

const float THRESHOLD = 0.2;
const float OVERLAY_OPACITY = 1.0;
const float SHAKE_MAGNITUDE = 0.05;

// Effect IDs (blue channel of the marker x 20)
const int EFFECT_NONE        = 0;
const int EFFECT_THRESHOLD   = 1;   // 0.05
const int EFFECT_INVERT      = 2;   // 0.10
const int EFFECT_SHAKE       = 3;   // 0.15
const int EFFECT_GLITCH      = 5;   // 0.25

void main() {
    // Hide the marker pixel itself: copy its right-hand neighbour
    if (ivec2(gl_FragCoord.xy) == ivec2(0, 0)) {
        fragColor = vec4(texelFetch(InSampler, ivec2(1, 0), 0).rgb, 1.0);
        return;
    }

    if (isErrorColor2(texture(InSampler, texCoord))) {
        fragColor = vec4(0.141, 0.078, 0.031, 1.0);
        return;
    }

    int effectId = int(round(texelFetch(DataSampler, ivec2(0, 0), 0).b * 20.0));
    vec3 color = texture(InSampler, texCoord).rgb;

    if (effectId == EFFECT_THRESHOLD) {
        float gray = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 overlay = vec3(step(THRESHOLD, gray));
        fragColor = vec4(mix(color, overlay, OVERLAY_OPACITY), 1.0);
    } else if (effectId == EFFECT_INVERT) {
        float gray = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 overlay = vec3(1.0 - step(THRESHOLD, gray));
        fragColor = vec4(mix(color, overlay, OVERLAY_OPACITY), 1.0);
    } else if (effectId == EFFECT_SHAKE) {
        float t = floor(GameTime * 24000.0);
        vec2 offset = vec2(
            fract(sin(t * 12.9898) * 43758.5453) - 0.5,
            fract(sin(t * 78.233)  * 43758.5453) - 0.5
        ) * SHAKE_MAGNITUDE * 2.0;
        fragColor = vec4(texture(InSampler, clamp(texCoord + offset, 0.0, 1.0)).rgb, 1.0);
    } else if (effectId == EFFECT_GLITCH) {
        const float SCALE_X = 2.1;
        const float SCALE_Y = 20.0;
        const int OCTAVES = 5;
        const float LACUNARITY = 2.0;
        const float CONTRAST = 1.6;
        const float BRIGHTNESS = -0.15;
        const float DISPLACE_MAGNITUDE = 0.05;
        const float CUTOFF = 0.5;
        const float CHROMA_SPREAD = 0.08;

        float t = GameTime * 10000.0;
        float tStep = floor(t);

        vec2 gridOffset = vec2(
            fract(sin(tStep * 127.1) * 43758.5453),
            fract(sin(tStep * 311.7) * 43758.5453)
        );

        vec3 p = vec3(texCoord.x * SCALE_X + gridOffset.x, texCoord.y * SCALE_Y + gridOffset.y, t);

        float n = 0.0;
        float amp = 1.0;
        for (int i = 0; i < OCTAVES; i++) {
            n = max(n, hash(floor(p)) * amp);
            p *= LACUNARITY;
            amp *= 0.5;
        }

        n = clamp((n - 0.5) * CONTRAST + 0.5 + BRIGHTNESS, 0.0, 1.0);

        float displacement = (n - 0.5) * 2.0;
        vec2 offset = vec2(0.0);
        if (abs(displacement) > CUTOFF) {
            offset = vec2(displacement) * DISPLACE_MAGNITUDE;
        } else {
            displacement = 0.0;
        }

        vec2 dir = length(offset) > 0.0 ? normalize(offset) : vec2(1.0, 0.0);
        vec2 chroma = dir * CHROMA_SPREAD * abs(displacement);

        float r = texture(InSampler, clamp(texCoord + offset - chroma, 0.0, 1.0)).r;
        float g = texture(InSampler, clamp(texCoord + offset,          0.0, 1.0)).g;
        float b = texture(InSampler, clamp(texCoord + offset + chroma, 0.0, 1.0)).b;

        fragColor = vec4(r, g, b, 1.0);
    } else {
        fragColor = vec4(color, 1.0);
    }
}