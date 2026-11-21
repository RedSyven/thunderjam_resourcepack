#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>
#include <minecraft:globals.glsl>
#include <minecraft:sample_lightmap.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 UV0;
layout(location = 3) in ivec2 UV2;

#ifndef OIT_ALPHA_ONLY
uniform sampler2D Sampler2;
#endif

layout(location = 0) out float sphericalVertexDistance;
layout(location = 1) out float cylindricalVertexDistance;
layout(location = 2) out vec4 vertexColor;
layout(location = 3) out vec2 texCoord0;

float hash13(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

void main() {
    vec3 pos = Position + ModelOffset;
    float time = GameTime * 1200.0;

    // Position relative to the camera's block: small numbers, precise anywhere in the world.
    vec3 rel = pos - CameraOffset;

    // Each block corner sits on the block grid: round() gives every grid point a stable ID.
    // Neighbouring blocks share corner points, so the canopy stays connected as it wobbles.
    ivec3 cornerCell = CameraBlockPos + ivec3(round(rel));
    float cornerPhase = hash13(vec3(cornerCell & ivec3(1023))) * 6.2831;

    // Global phase from world XZ — wind travelling across the tree
    float phase = dot(vec2(cornerCell.xz & ivec2(255)), vec2(7.31, 13.17));

    // Main wind direction
    float gust = sin(time * 8.5 + phase * 0.5) * 0.5 + 0.5;
    float windX = sin(time * 2.5 + phase * 1.2) * 0.12
                + sin(time * 1.1 + phase * 0.7) * 0.08;
    float windZ = sin(time * 2.0 + phase * 1.5) * 0.06
                + cos(time * 1.4 + phase * 0.9) * 0.04;
    float windY = sin(time * 2.3 + phase * 1.3) * 0.06
                + cos(time * 1.2 + phase * 0.8) * 0.04;

    // Gusting — periodic surges
    windX *= 1.0 + gust * 0.8;
    windZ *= 1.0 + gust * 0.5;
    windY *= 1.0 + gust * 1.0;

    // Per-corner shake — each grid point jitters independently
    float shakeX = sin(time * 9.0 + cornerPhase) * 0.08
                 + sin(time * 7.0 + cornerPhase * 2.3) * 0.05;
    float shakeZ = cos(time * 8.0 + cornerPhase * 1.7) * 0.07
                 + cos(time * 10.0 + cornerPhase * 0.9) * 0.04;
    float shakeY = sin(time * 9.5 + cornerPhase * 3.1) * 0.035;

    // Flutter — fast, tiny detail
    float flutter = dot(fract(rel * 0.5), vec3(3.7, 2.1, 4.3));
    float flutterX = sin(time * 8.0 + flutter + phase * 3.0) * 0.02;
    float flutterZ = cos(time * 7.0 + flutter + phase * 2.7) * 0.02;
    float flutterY = sin(time * 9.0 + flutter + phase * 4.0) * 0.02;

    // Combine: wind + per-corner shake + flutter
    pos.x += windX + shakeX + flutterX;
    pos.z += windZ + shakeZ + flutterZ;
    pos.y += windY + shakeY + flutterY;

    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);

    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    #ifndef OIT_ALPHA_ONLY
    vertexColor = Color * sample_lightmap(Sampler2, UV2);
    #else
    vertexColor = Color;
    #endif
    texCoord0 = UV0;
}