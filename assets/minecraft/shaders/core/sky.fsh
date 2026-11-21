#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:globals.glsl>

layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
layout(location = 2) in vec3 skyDir;

layout(location = 0) out vec4 fragColor;

const float FLASH_INTERVAL = 0.00008;  // GameTime units between potential flashes (tune)
const float FLASH_CHANCE = 0.3;        // 0-1, fraction of intervals that actually flash
const float FLASH_DECAY = 0.4;         // smaller = longer afterglow

const vec3 STORM_DARK  = vec3(0.005, 0.007, 0.012);
const vec3 STORM_LIGHT = vec3(0.06, 0.07, 0.10);
const float STORM_SPEED = 2400.0;
const float STORM_SCALE = 6.0;

float hashSky(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noiseSky(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hashSky(i + vec3(0,0,0)), hashSky(i + vec3(1,0,0)), f.x),
            mix(hashSky(i + vec3(0,1,0)), hashSky(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hashSky(i + vec3(0,0,1)), hashSky(i + vec3(1,0,1)), f.x),
            mix(hashSky(i + vec3(0,1,1)), hashSky(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

float fbmSkyAnimated(vec3 p, float t) {
    float n = noiseSky(p + vec3(t * 0.3, t * 0.5, t * 0.2)) * 0.5
            + noiseSky(p * 2.03 + vec3(-t * 0.7, t * 0.3, t * 0.4)) * 0.25
            + noiseSky(p * 4.07 + vec3(t * 0.5, -t * 0.6, t * 0.8)) * 0.125
            + noiseSky(p * 8.11 + vec3(-t * 1.2, t * 0.9, -t * 1.1)) * 0.0625;
    return n / 0.9375;
}

float computeFlash(float t) {
    float window = floor(t / FLASH_INTERVAL);
    float windowPos = fract(t / FLASH_INTERVAL);

    float fireRoll = fract(sin(window * 91.37) * 43758.5453);
    if (fireRoll > FLASH_CHANCE) return 0.0;

    // Quick rise, slower fall.
    float rise = smoothstep(0.0, 0.05, windowPos);
    float fall = 1.0 - smoothstep(0.05, FLASH_DECAY, windowPos);
    return rise * fall;
}

void main() {
    vec4 baseSky = apply_fog(ColorModulator, sphericalVertexDistance, cylindricalVertexDistance,
                             0.0, FogSkyEnd, FogSkyEnd, FogSkyEnd, FogColor);

    float t = GameTime * STORM_SPEED;
    vec3 samplePos = skyDir * STORM_SCALE;
    float n = fbmSkyAnimated(samplePos, t);

    vec3 stormColor = mix(STORM_DARK, STORM_LIGHT, smoothstep(0.5, 0.6, n));

    float flash = computeFlash(GameTime);
    vec3 finalColor = stormColor * (1.0 + vec3(0.85, 0.92, 1.05) * flash * 8.0);

    fragColor = vec4(finalColor, baseSky.a);
}