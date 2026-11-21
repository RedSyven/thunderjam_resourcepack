#version 330
#extension GL_ARB_separate_shader_objects : require

layout(std140) uniform LightmapInfo {
    float SkyFactor;
    float BlockFactor;
    float NightVisionFactor;
    float DarknessScale;
    float BossOverlayWorldDarkeningFactor;
    float BrightnessFactor;
    vec3 BlockLightTint;
    vec3 SkyLightColor;
    vec3 AmbientColor;
    vec3 NightVisionColor;
} lightmapInfo;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

float get_brightness(float level) {
    return level / (4.0 - 3.0 * level);
}

vec3 notGamma(vec3 color) {
    float maxComponent = max(max(color.x, color.y), color.z);
    if (maxComponent <= 0.0) return color;   // guard: avoids 0/0 = NaN on fully black texels
    float maxInverted = 1.0 - maxComponent;
    float maxScaled = 1.0 - maxInverted * maxInverted * maxInverted * maxInverted;
    return color * (maxScaled / maxComponent);
}

void main() {
    float blockLevel = floor(texCoord.x * 16.0) / 15.0;
    float skyLevel   = floor(texCoord.y * 16.0) / 15.0;

    float blockBrightness = get_brightness(blockLevel) * lightmapInfo.BlockFactor;
    float skyBrightness   = get_brightness(skyLevel)   * lightmapInfo.SkyFactor;

    // Custom warm block-light curve (replaces vanilla's BlockLightTint mix)
    vec3 color = vec3(
        blockBrightness,
        blockBrightness * ((blockBrightness * 0.6 + 0.4) * 0.6 + 0.4),
        blockBrightness * (blockBrightness * blockBrightness * 0.6 + 0.4)
    );

    // Old overworld path had no ambient term (AmbientLightFactor was 0 there).
    // To restore ambient light in other dimensions, uncomment:
    // color = max(color, lightmapInfo.AmbientColor);

    color += lightmapInfo.SkyLightColor * skyBrightness;
    color = mix(color, vec3(0.75), 0.04);

    // Boss overlay darkening (was DarkenWorldFactor, overworld-only)
    color = mix(color, color * vec3(0.7, 0.6, 0.6), lightmapInfo.BossOverlayWorldDarkeningFactor);

    // Night vision: old behavior, normalize the brightest channel toward 1
    if (lightmapInfo.NightVisionFactor > 0.0) {
        float maxComponent = max(color.r, max(color.g, color.b));
        if (maxComponent > 0.0 && maxComponent < 1.0) {
            color = mix(color, color / maxComponent, lightmapInfo.NightVisionFactor);
        }
    }

    // Darkness effect (was overworld-only)
    color -= vec3(lightmapInfo.DarknessScale);

    color = clamp(color, 0.0, 1.0);
    color = mix(color, notGamma(color), lightmapInfo.BrightnessFactor);
    color = mix(color, vec3(0.75), 0.04);

    // Pitch-black world: everything scaled by a block-light-only curve
    float smoothBrightness = get_brightness(texCoord.x) * lightmapInfo.BlockFactor;
    float darkBlend = pow(smoothstep(0.0, 0.4, smoothBrightness), 0.6);
    fragColor = vec4(color * darkBlend, 1.0);
}