#version 330
#extension GL_ARB_separate_shader_objects : require
#extension GL_KHR_shader_subgroup_basic : require

#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
#include <minecraft:fog.glsl>
#include <minecraft:sample_lightmap.glsl>
#endif

#ifdef IS_SEE_THROUGH
#include <minecraft:globals.glsl>
#endif

#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 UV0;
#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
layout(location = 3) in ivec2 UV2;
uniform sampler2D Sampler2;
#endif

#ifndef IS_GUI
layout(location = 0) out float sphericalVertexDistance;
#endif
#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
layout(location = 1) out float cylindricalVertexDistance;
#endif
layout(location = 2) out vec4 vertexColor;
layout(location = 3) out vec2 texCoord0;
#ifndef IS_GUI
layout(location = 4) out vec3 relPos;      // camera-relative position (per-quad seed in fsh)
layout(location = 5) out vec2 quadUV;      // 0-1 across the quad (corner from subgroup lane)
#endif
layout(location = 6) flat out int sentinel;

// ---------- Sentinels (detected on raw vertex Color) ----------
const int SENTINEL_NONE       = 0;
const int SENTINEL_ERROR      = 1;
const int SENTINEL_LIDAR      = 2;
const int SENTINEL_RAIN_GLASS = 3;
const int SENTINEL_CLOUD      = 4;

int detectSentinel(vec4 c) {
    if (c.r > 0.95 && c.g > 0.06 && c.g < 0.065 && c.b > 0.06 && c.b < 0.065) return SENTINEL_ERROR;
    if (c.r > 0.06 && c.r < 0.065 && c.g > 0.95 && c.b < 0.05)                return SENTINEL_LIDAR;
    if (c.r > 0.06 && c.r < 0.065 && c.g > 0.06 && c.g < 0.065 && c.b > 0.95) return SENTINEL_RAIN_GLASS;
    if (c.r > 0.95 && c.g > 0.95 && c.b > 0.06 && c.b < 0.065)                return SENTINEL_CLOUD;
    return SENTINEL_NONE;
}

const vec2 CORNER_UVS[4] = vec2[4](
    vec2(0.0, 1.0),
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0)
);

#ifdef IS_SEE_THROUGH
// ---------- Lightning jitter (see-through lidar) ----------
const float LIGHTNING_PULSE_SPEED = 8.0;
const float LIGHTNING_PULSE_MAX   = 40.0;
const float LIGHTNING_PULSE_WIDTH = 12.0;
const float LIGHTNING_JITTER_XZ   = 0.1;
const float LIGHTNING_JITTER_Y    = 0.05;

// Spatial frequency of the jitter noise (per block): one small quad's corners sample
// nearly the same value, neighbouring orbs differ.
const float JITTER_NOISE_FREQ = 2.0;

float vhash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(vhash(i + vec3(0,0,0)), vhash(i + vec3(1,0,0)), f.x),
            mix(vhash(i + vec3(0,1,0)), vhash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(vhash(i + vec3(0,0,1)), vhash(i + vec3(1,0,1)), f.x),
            mix(vhash(i + vec3(0,1,1)), vhash(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

vec3 lightningJitter(vec3 worldPos, float pulseTime, float dist) {
    vec3 q = worldPos * JITTER_NOISE_FREQ;
    float pulseOffset = vnoise(q + 91.1) * 2.0 - 1.0;
    float offsetTime = pulseTime + pulseOffset;

    float cycleLength = LIGHTNING_PULSE_MAX + LIGHTNING_PULSE_WIDTH * 2.0;
    float pulseRadius = mod(offsetTime * LIGHTNING_PULSE_SPEED, cycleLength) - LIGHTNING_PULSE_WIDTH;
    float pulseIntensity = pow(1.0 - smoothstep(0.0, LIGHTNING_PULSE_WIDTH, abs(dist - pulseRadius)), 2.0);

    vec3 r = vec3(vnoise(q), vnoise(q + 17.3), vnoise(q + 41.7)) * 2.0 - 1.0;
    return vec3(
        r.x * pulseIntensity * LIGHTNING_JITTER_XZ,
        -abs(r.y) * pulseIntensity * LIGHTNING_JITTER_Y,
        r.z * pulseIntensity * LIGHTNING_JITTER_XZ
    );
}
#endif

void main() {
#ifndef IS_GUI
    quadUV = CORNER_UVS[int(gl_SubgroupInvocationID % 4u)];
    relPos = Position;
#endif

#ifdef IS_GRAYSCALE
    sentinel = SENTINEL_NONE;   // TTF text was never part of the effect system
#else
    sentinel = detectSentinel(Color);
#endif

    vec3 pos = Position;

#ifdef IS_SEE_THROUGH
    if (sentinel == SENTINEL_LIDAR) {
        float pulseTime = GameTime * 1200.0;
        vec3 worldPos = vec3(CameraBlockPos) - CameraOffset + Position;   // verified formula
        pos += lightningJitter(worldPos, pulseTime, length(pos));
    }
#endif

    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    // sentinel quads keep their raw color; everything else gets the lightmap
    vertexColor = (sentinel != SENTINEL_NONE) ? Color : Color * sample_lightmap(Sampler2, UV2);
#elif defined(IS_SEE_THROUGH)
    sphericalVertexDistance = length(pos);   // identical to fog_spherical_distance; no fog.glsl here
    vertexColor = Color;
#else
    vertexColor = Color;
#endif

    texCoord0 = UV0;
}