#version 330
#extension GL_ARB_separate_shader_objects : require

// Grid cells per block used to quantize each quad's center before hashing.
#define SEED_CELLS_PER_BLOCK 4.0

#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
#include <minecraft:fog.glsl>
#endif

#ifndef IS_GUI
#include <minecraft:globals.glsl>
#include <minecraft:thunderstorm_particle_effects.glsl>
#endif

#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>

uniform sampler2D Sampler0;

#ifndef IS_GUI
layout(location = 0) in float sphericalVertexDistance;
#endif
#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
layout(location = 1) in float cylindricalVertexDistance;
#endif
layout(location = 2) in vec4 vertexColor;
layout(location = 3) in vec2 texCoord0;
#ifndef IS_GUI
layout(location = 4) in vec3 relPos;
layout(location = 5) in vec2 quadUV;
#endif
layout(location = 6) flat in int sentinel;

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

const int SENTINEL_NONE       = 0;
const int SENTINEL_ERROR      = 1;
const int SENTINEL_LIDAR      = 2;
const int SENTINEL_RAIN_GLASS = 3;
const int SENTINEL_CLOUD      = 4;

#ifndef IS_GUI
// Per-quad seed from the quad's world-space center (stable under re-sorting / batching).
// The UV -> position map is affine across a planar quad, so derivatives give the quad's axes.
float computeQuadPhase() {
    vec3 dpdx = dFdx(relPos);
    vec3 dpdy = dFdy(relPos);
    vec2 dux  = dFdx(quadUV);
    vec2 duy  = dFdy(quadUV);
    float det = dux.x * duy.y - dux.y * duy.x;

    vec3 centerRel = relPos;
    float quadSize = 0.25;
    if (abs(det) > 1e-12) {
        vec3 dPdu = ( duy.y * dpdx - dux.y * dpdy) / det;
        vec3 dPdv = (-duy.x * dpdx + dux.x * dpdy) / det;
        centerRel = relPos + dPdu * (0.5 - quadUV.x) + dPdv * (0.5 - quadUV.y);
        quadSize = max(length(dPdu), length(dPdv));   // quad's world-space size
    }

    // Cell size grows with the quad: small quads get fine cells, big quads coarse cells.
    // Two quad-widths per cell keeps the center comfortably inside one cell.
    float cellSize = max(quadSize * 2.0, 1.0 / SEED_CELLS_PER_BLOCK);

    vec3 centerWorld = vec3(CameraBlockPos) - CameraOffset + centerRel;
    return hash(floor(centerWorld / cellSize)) * 500.0;
}
#endif

vec4 calculateFinalColor(vec4 color) {
    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    #endif

    #if !defined(IS_SEE_THROUGH) && !defined(IS_GUI)

    #ifdef OIT_ACCUMULATE
    vec4 fogColor = vec4(FogColor.rgb * color.a, FogColor.a);
    #else
    vec4 fogColor = FogColor;
    #endif

    color = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
    #endif

    return color;
}

// Effects skip fog and ColorModulator but still participate in OIT.
vec4 calculateEffectColor(vec4 color) {
    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    #endif
    return color;
}

void writeOutput(vec4 color, bool isEffect) {
    #ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = isEffect ? calculateEffectColor(color) : calculateFinalColor(color);
    #endif
}

void main() {
#ifndef IS_GUI
    // Derivatives must be taken before any discard / divergent branch.
    float quadPhase = computeQuadPhase();
#endif

#ifndef IS_SEE_THROUGH
    // error-colored text is hidden (world + GUI)
    if (sentinel == SENTINEL_ERROR) {
        discard;
    }
#endif

#ifndef IS_GUI
    #ifdef IS_SEE_THROUGH
    bool isEffect = (sentinel == SENTINEL_LIDAR);
    #else
    bool isEffect = (sentinel == SENTINEL_LIDAR || sentinel == SENTINEL_RAIN_GLASS || sentinel == SENTINEL_CLOUD);
    #endif

    if (isEffect) {
        float time = GameTime * 1200.0;
        vec4 result;

        if (sentinel == SENTINEL_CLOUD) {
            result = effectCloud(quadUV, time, quadPhase);
        } else if (sentinel == SENTINEL_RAIN_GLASS) {
            result = effectRainGlass(quadUV, time, quadPhase);
        } else {
            vec2 centered = quadUV - 0.5;
            float d = length(centered) * 2.0;
            float z = sqrt(max(1.0 - d * d, 0.0));
            float angle = atan(centered.y, centered.x);

            #ifdef IS_SEE_THROUGH
            // See-through lidar: lightning orb (no Fog binding for mode detection)
            result = effectLightningOrb(d, angle, z, time, quadPhase, sphericalVertexDistance);
            // result = effectGlitched(quadUV, quadPhase, time, sphericalVertexDistance);
            // result = effectBlueLightning(d, angle, z, time, quadPhase);
            #else
            // World lidar: blue lightning
            result = effectBlueLightning(d, angle, z, time, quadPhase);
            #endif
        }

        if (result.a < ALPHA_CUTOFF) {
            discard;
        }
        writeOutput(result, true);
        return;
    }
#endif

    #ifdef IS_GRAYSCALE
    vec4 texColor = texture(Sampler0, texCoord0).rrrr;
    #else
    vec4 texColor = texture(Sampler0, texCoord0);
    #endif

    vec4 color = texColor * vertexColor * ColorModulator;

    if (color.a < 0.1) {
        discard;
    }

    writeOutput(color, false);
}