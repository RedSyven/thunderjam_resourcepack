#version 330
#extension GL_ARB_separate_shader_objects : require

// If this pipeline turns out not to bind Globals (compile error naming Globals),
// comment out USE_SCREEN_SIZE: the marker then uses a fixed small size instead of exactly 1 pixel.
#define USE_SCREEN_SIZE

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>
#include <minecraft:sample_lightmap.glsl>
#ifdef USE_SCREEN_SIZE
#include <minecraft:globals.glsl>
#endif

layout(location = 0) in vec3 Position;
layout(location = 1) in vec2 UV0;
layout(location = 2) in vec4 Color;
layout(location = 3) in ivec2 UV2;

#ifndef OIT_ALPHA_ONLY
uniform sampler2D Sampler2;
#endif

layout(location = 0) out float sphericalVertexDistance;
layout(location = 1) out float cylindricalVertexDistance;
layout(location = 2) out vec2 texCoord0;
layout(location = 3) out vec4 vertexColor;
layout(location = 4) flat out int isMarker;
layout(location = 5) flat out float effectId;

const vec2 CORNERS[4] = vec2[4](
    vec2(0.0, 1.0),
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0)
);

void main() {
    // Marker particle: color (0.85, 0.85, id, 1.0), snapped to steps of 1/20
    ivec4 snapped = ivec4(round(Color * 20.0));
    isMarker = int(snapped.r == 17 && snapped.g == 17 && snapped.a == 20);
    effectId = float(snapped.b) / 20.0;

    if (isMarker == 1) {
    #ifdef USE_SCREEN_SIZE
        vec2 markerSize = 2.0 / ScreenSize;   // exactly 1 pixel in NDC
    #else
        vec2 markerSize = vec2(0.01);         // fallback: a few pixels, always covers pixel (0,0)
    #endif
        // NDC (-1,-1) = framebuffer pixel (0,0) on both GL and Vulkan.
        // z = 0.9999 = near plane under 26.2+'s reversed depth, so nothing occludes the marker.
        gl_Position = vec4(-1.0 + CORNERS[gl_VertexIndex % 4] * markerSize, 0.9999, 1.0);

        sphericalVertexDistance = 0.0;
        cylindricalVertexDistance = 0.0;
        texCoord0 = vec2(0.0);
        vertexColor = vec4(0.0);
        return;
    }

    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    sphericalVertexDistance = fog_spherical_distance(Position);
    cylindricalVertexDistance = fog_cylindrical_distance(Position);
    texCoord0 = UV0;
    #ifndef OIT_ALPHA_ONLY
    vertexColor = Color * sample_lightmap(Sampler2, UV2);
    #else
    vertexColor = Color;
    #endif
}