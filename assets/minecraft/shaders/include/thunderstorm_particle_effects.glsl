#ifndef THUNDERSTORM_PARTICLE_EFFECTS_GLSL
#define THUNDERSTORM_PARTICLE_EFFECTS_GLSL

const float GRADIENT_MAX_DIST = 30.0;

const float PULSE_SPEED = 8.0;
const float PULSE_MAX = 40.0;
const float PULSE_WIDTH = 12.0;
const float PULSE_DARKEN = 0.8;

const int   FILAMENT_COUNT = 10;
const float FILAMENT_TIME_SCALE = 2.5;
const float FILAMENT_THICKNESS = 0.08;
const float FILAMENT_THRESHOLD = 0.4;

const float CORE_GLOW_RADIUS = 0.1;
const float CORE_HOT_RADIUS = 0.05;
const float CORE_NOISE_SCALE = 0.5;
const float CORE_TIME_SCALE = 0.7;
const float CORE_GLOW_THRESHOLD = 0.2;
const float CORE_HOT_THRESHOLD = 0.3;

const float WAVE_ANGULAR_SCALE = 0.7;
const float WAVE_RADIAL_SCALE = 10.0;
const float WAVE_SPEED = 8.5;
const float WAVE_SOLID_RADIUS = 0.0;
const float WAVE_OUTER_RADIUS = 0.9;
const float WAVE_CENTER_THRESHOLD = 0.2;
const float WAVE_EDGE_THRESHOLD = 1.01;

//detail reduction on lidar points for better performance/visual clarity
const float LIGHTNING_DETAIL_DIST = 3.0;
const float LIGHTNING_FADE_WIDTH = 4.0;
const float WAVE_FADE_DIST = 8.0;
const float WAVE_FADE_WIDTH = 6.0;
const float SOLID_RADIUS = 0.4;

const float GLITCH_MAX_DIST = 12.0;
const float GLITCH_BURST_RATE = 1.5;
const float GLITCH_BURST_THRESHOLD = 0.5;
const float GLITCH_NOISE_RATE = 10.0;
const float GLITCH_BAND_HEIGHT = 10.0;
const float GLITCH_BAND_ACTIVITY = 0.3;
const float GLITCH_DISPLACE_MAG = 0.6;
const float GLITCH_DISC_RADIUS = 0.4;

const float BLUE_GLOW_THRESHOLD = 0.2;

const float ALPHA_CUTOFF = 0.01;
const float TAU = 6.2831853;
const float PI = 3.1415927;

const vec3 FILAMENT_COLOR = vec3(1.0, 0.9, 1.0);
const vec3 CORE_GLOW_COLOR = vec3(1.0, 0.95, 1.0);
const vec3 CORE_HOT_COLOR = vec3(1.0);
const vec3 BLUE_GRADIENT = vec3(0.4, 0.6, 1.0);
const vec3 GLITCH_BASE_COLOR = vec3(0.7);
const vec3 GLITCH_SHIFT_COLOR = vec3(0.4);

const int MODE_LIGHTNING = 0;
const int MODE_GLITCHED = 1;
const int MODE_BLUE = 2;
const int MODE_DEFAULT = 3;

const vec2 RAIN_PIXEL_GRID = vec2(96.0, 88.0);
const float RAIN_TIME_STEPS = 15.0;
const int RAIN_NUM_DROPS = 80;
const vec3 RAIN_DROP_COLOR = vec3(0.20, 0.25, 0.32);

const float CLOUD_CORE_OPACITY = 0.3;

// ---------- Hash / noise ----------

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float rainHash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 rainHash2(vec2 p) {
    return vec2(rainHash(p), rainHash(p.yx + vec2(53.7, 19.3)));
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

float fbm(vec3 p) {
    float n = noise3D(p) * 0.5
            + noise3D(p * 2.0) * 0.25
            + noise3D(p * 4.0) * 0.125;
    return n / 0.875;
}


// ---------- Sentinel colors ----------

bool isErrorColor(vec4 col) {
    return col.r > 0.95 
    && col.g > 0.06 && col.g < 0.065
    && col.b > 0.06 && col.b < 0.065;
}

bool isErrorColor2(vec4 col) {
    return col.r > 0.95 
    && col.g > 0.12 && col.g < 0.13
    && col.b > 0.12 && col.b < 0.13;
}

bool isCloudColor(vec4 col) {
    return col.r > 0.95
        && col.g > 0.95
        && col.b > 0.06 && col.b < 0.065;
}

bool isRainGlassColor(vec4 col) {
    return col.r > 0.06 && col.r < 0.065
        && col.g > 0.06 && col.g < 0.065
        && col.b > 0.95;
}

bool isLidarColor(vec4 col) {
    return col.r > 0.06 && col.r < 0.065 && col.g > 0.95 && col.b < 0.05;
}

// ---------- Cloud layer -----------

float hashDither(ivec2 p) {
    uint x = uint(p.x);
    uint y = uint(p.y);
    uint h = x * 73856093u ^ y * 19349663u;
    h = (h ^ (h >> 13u)) * 1274126177u;
    h = h ^ (h >> 16u);
    return float(h) / 4294967295.0;
}

vec4 effectCloud(vec2 quadUV, float time, float quadPhase) {
    float r1 = fract(sin(quadPhase * 12.9898) * 43758.5453);
    float r2 = fract(sin(quadPhase * 78.233)  * 43758.5453);
    float r3 = fract(sin(quadPhase * 39.347)  * 43758.5453);
    float r4 = fract(sin(quadPhase * 95.171)  * 43758.5453);

    vec2 noiseOffset = vec2(r1, r2) * 100.0;
    float driftAngle = r3 * 6.2831853;
    float driftSpeed = 0.5 + r4 * 0.9;
    vec2 driftDir = vec2(cos(driftAngle), sin(driftAngle)) * driftSpeed;
    float morphRate = 0.1 + r1 * 0.2;

    float t = time * 1.5;
    vec3 samplePos = vec3(
        quadUV * 3.0 + noiseOffset + driftDir * t,
        t * morphRate + noiseOffset.x
    );
    float n = fbm(samplePos);

    vec2 centered = quadUV - 0.5;
    float edgeDist = max(abs(centered.x), abs(centered.y)) * 2.0;
    float edgeFade = 1.0 - smoothstep(0.5, 1.0, edgeDist);
    float density = n * edgeFade;

    const float DITHER_RESOLUTION = 1024.0;

    ivec2 quadOffset = ivec2(
        int(fract(sin(quadPhase * 41.7) * 43758.5453) * 1000.0),
        int(fract(sin(quadPhase * 93.1) * 43758.5453) * 1000.0)
    );

    ivec2 dPx = ivec2(floor(quadUV * DITHER_RESOLUTION));
    float dither = hashDither(dPx + quadOffset);

    // Dither only the in-between band: core is always opaque, far edges always discarded.
    const float CORE_DENSITY = 0.7;
    const float EDGE_DENSITY = 0.1;
    const float DITHER_RANGE = 1.0;

    float edgeness = 1.0 - smoothstep(EDGE_DENSITY, CORE_DENSITY, density);
    float coreThreshold = (1.0 - CLOUD_CORE_OPACITY) * dither;
    float edgeThreshold = dither * DITHER_RANGE * edgeness;
    float threshold = EDGE_DENSITY + max(coreThreshold, edgeThreshold);

    if (density < threshold) discard;

    vec3 cloudColor = mix(vec3(0.0), vec3(0.15), density);
    return vec4(cloudColor, 1.0);
}

// ---------- Rain on glass ----------

vec2 oneDrop(vec2 uv, float time, float id, float phase) {
    float cycleRate = 0.3 + rainHash(vec2(id * 7.13 + 71.0, phase)) * 0.4;
    float dropTime = time * cycleRate + rainHash(vec2(id * 7.13 + 53.0, phase)) * 10.0;
    float cycleNumber = floor(dropTime);
    float cyclePos = fract(dropTime);

    vec2 cycleRnd       = rainHash2(vec2(id * 7.13 + 1.0,  cycleNumber * 3.71 + 1.0));
    float slideSpeed    = 0.1 + rainHash(vec2(id * 7.13 + 17.0, cycleNumber * 3.71 + 17.0)) * 0.2;
    float stickDuration = 0.2 + rainHash(vec2(id * 7.13 + 31.0, cycleNumber * 3.71 + 31.0)) * 0.5;

    float dropX = cycleRnd.x;
    float startY = cycleRnd.y;

    float dropY;
    float lifeFade;
    bool sliding = false;

    if (cyclePos < stickDuration) {
        dropY = startY;
        lifeFade = smoothstep(0.0, 0.1, cyclePos);
    } else {
        float slideElapsed = cyclePos - stickDuration;
        dropY = startY - slideElapsed * slideSpeed;
        lifeFade = 1.0 - smoothstep(0.85, 1.0, cyclePos);
        if (dropY < 0.0) lifeFade = 0.0;
        sliding = true;
    }

    vec2 diff = uv - vec2(dropX, dropY);
    float pxX = abs(diff.x) * RAIN_PIXEL_GRID.x;
    float pxY = diff.y * RAIN_PIXEL_GRID.y;

    float intensity = step(max(pxX, abs(pxY)), 0.5) * lifeFade;

    if (sliding && lifeFade > 0.0) {
        float trailLen = floor(mix(5.0, 10.0, (slideSpeed - 0.3) / 0.5));
        if (pxX < 0.5 && pxY > 0.5 && pxY < trailLen + 0.5) {
            float distFromHead = floor(pxY + 0.5);
            float t = (distFromHead - 1.0) / max(trailLen - 1.0, 1.0);
            intensity = max(intensity, mix(0.6, 0.5, t) * lifeFade);
        }
    }

    return vec2(intensity, 0.0);
}

vec4 effectRainGlass(vec2 uv, float time, float phase) {
    uv = floor(uv * RAIN_PIXEL_GRID) / RAIN_PIXEL_GRID;
    time = floor(time * RAIN_TIME_STEPS) / RAIN_TIME_STEPS;

    float intensity = 0.0;
    for (int i = 0; i < RAIN_NUM_DROPS; i++) {
        intensity = max(intensity, oneDrop(uv, time, float(i), phase).x);
    }

    return vec4(RAIN_DROP_COLOR * intensity, step(ALPHA_CUTOFF, intensity));
}


// ---------- Lightning shared helpers ----------

vec3 distanceGradient(float t) {
    if (t < 0.25) return mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 0.5, 0.0), t * 4.0);
    if (t < 0.50) return mix(vec3(1.0, 0.5, 0.0), vec3(1.0, 1.0, 0.0), (t - 0.25) * 4.0);
    if (t < 0.75) return mix(vec3(1.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), (t - 0.50) * 4.0);
    return mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), (t - 0.75) * 4.0);
}

float computePulseIntensity(float dist, float time) {
    float cycleLength = PULSE_MAX + PULSE_WIDTH * 2.0;
    float radius = mod(time * PULSE_SPEED, cycleLength) - PULSE_WIDTH;
    return pow(1.0 - smoothstep(0.0, PULSE_WIDTH, abs(dist - radius)), 2.0);
}

vec3 polarToNoiseSpace(float d, float angle, float time, float scale, float timeScale) {
    return vec3(
        cos(angle) * WAVE_ANGULAR_SCALE * scale,
        sin(angle) * WAVE_ANGULAR_SCALE * scale,
        d * WAVE_RADIAL_SCALE * scale - time * WAVE_SPEED * timeScale
    );
}

float wavefrontNoise(float d, float angle, float time) {
    return fbm(polarToNoiseSpace(d, angle, time, 1.0, 1.0));
}

float wavefrontThreshold(float d) {
    return mix(WAVE_CENTER_THRESHOLD, WAVE_EDGE_THRESHOLD,
               smoothstep(WAVE_SOLID_RADIUS, WAVE_OUTER_RADIUS, d));
}

float computeWavefront(float d, float angle, float time) {
    return step(wavefrontThreshold(d), wavefrontNoise(d, angle, time));
}

float computeCoreLayer(float d, float coreNoise, float radius, float threshold) {
    if (d >= radius) return 0.0;
    float mask = mix(1.01, threshold, smoothstep(0.0, radius, d));
    return step(coreNoise, mask);
}

float computeFilaments(float d, float angle, float time, float quadPhase) {
    float total = 0.0;
    for (int i = 0; i < FILAMENT_COUNT; i++) {
        float seed = float(i) * 17.3 + quadPhase;
        float lifePhase = floor(time * FILAMENT_TIME_SCALE + seed);
        float lifeFract = fract(time * FILAMENT_TIME_SCALE + seed);
        float baseAngle = fract(sin(lifePhase * 7.13 + seed) * 43758.5453) * TAU;

        float wander = sin(d * 12.0 + lifePhase * 3.1 + seed) * 0.25
                     + sin(d * 24.0 - lifePhase * 2.3 + seed * 0.7) * 0.15
                     + sin(d * 48.0 + lifePhase * 4.7 + seed) * 0.08
                     + sin(d * 85.0 - seed * 1.3) * 0.04;

        float angleDiff = abs(mod(angle - (baseAngle + wander) + PI, TAU) - PI);
        float thickness = FILAMENT_THICKNESS + 0.05 * (1.0 - d);
        float filament = 1.0 - smoothstep(0.0, thickness, angleDiff);

        float filEnd = 0.3 + fract(sin(seed * 11.7) * 43758.5453) * 0.3;
        float radialFade = 1.0 - smoothstep(filEnd - 0.15, filEnd, d);
        float lifeFade = sin(lifeFract * PI);

        total = max(total, step(FILAMENT_THRESHOLD, filament * radialFade * lifeFade));
    }
    return total;
}


// ---------- Lightning orb ----------

vec4 effectLightningOrb(float d, float angle, float z, float pulseTime, float quadPhase, float sphericalDist) {
    float t = clamp(sphericalDist / GRADIENT_MAX_DIST, 0.0, 1.0);
    float pulseOffset = fract(sin(quadPhase * 73.5) * 43758.5453) * 0.3 - 0.15;
    float darken = computePulseIntensity(sphericalDist, pulseTime + pulseOffset) * PULSE_DARKEN;
    vec3 gradient = mix(distanceGradient(t), vec3(0.0), darken);

    float wavefront = computeWavefront(d, angle, pulseTime + quadPhase);
    float solid = step(d, SOLID_RADIUS);
    float waveFade = 1.0 - smoothstep(WAVE_FADE_DIST - WAVE_FADE_WIDTH,
                                       WAVE_FADE_DIST, sphericalDist);
    float body = mix(solid, wavefront, waveFade) * z;

    vec3 col = gradient * body;
    float alpha = body;

    if (sphericalDist < LIGHTNING_DETAIL_DIST) {
        float detailFade = 1.0 - smoothstep(LIGHTNING_DETAIL_DIST - LIGHTNING_FADE_WIDTH,
                                            LIGHTNING_DETAIL_DIST, sphericalDist);

        float filaments = computeFilaments(d, angle, pulseTime * 2.0 + quadPhase, quadPhase) * detailFade;
        float coreNoise = fbm(polarToNoiseSpace(d, angle, pulseTime + quadPhase, CORE_NOISE_SCALE, CORE_TIME_SCALE));
        float centerGlow = computeCoreLayer(d, coreNoise, CORE_GLOW_RADIUS, CORE_GLOW_THRESHOLD) * detailFade;
        float centerHot  = computeCoreLayer(d, coreNoise, CORE_HOT_RADIUS,  CORE_HOT_THRESHOLD)  * detailFade;

        col = mix(col, mix(FILAMENT_COLOR,  vec3(0.0), darken), filaments);
        col = mix(col, mix(CORE_GLOW_COLOR, vec3(0.0), darken), centerGlow);
        col = mix(col, mix(CORE_HOT_COLOR,  vec3(0.0), darken), centerHot);

        alpha = max(max(centerGlow, centerHot), max(filaments, alpha));
    }

    return vec4(col, alpha);
}


// ---------- Glitched ----------

vec2 computeGlitchDisplacement(float pulseTime, vec2 quadUV, float quadPhase) {
    float burstPhase = floor((pulseTime + quadPhase * 0.3) * GLITCH_BURST_RATE);
    float burstTrigger = fract(sin(burstPhase * 73.5) * 43758.5453);
    if (burstTrigger <= GLITCH_BURST_THRESHOLD) return vec2(0.0);

    float glitchTime = floor(pulseTime * GLITCH_NOISE_RATE);
    vec2 quantized = floor(vec2(quadUV.x * 0.3, quadUV.y * GLITCH_BAND_HEIGHT));

    float bandActivity = hash(vec3(quantized, glitchTime + quadPhase + 91.2));
    if (bandActivity <= GLITCH_BAND_ACTIVITY) return vec2(0.0);

    float n1r = hash(vec3(quantized, glitchTime + quadPhase));
    float n2r = hash(vec3(quantized * 2.0, glitchTime * 1.3 + quadPhase));
    float mapR = clamp((max(n1r, n2r) - 0.5) * 2.8 + 0.25, 0.0, 1.0);

    float n1g = hash(vec3(quantized, glitchTime + quadPhase + 53.7));
    float n2g = hash(vec3(quantized * 2.0, glitchTime * 1.3 + quadPhase + 53.7));
    float mapG = clamp((max(n1g, n2g) - 0.5) * 2.8 + 0.25, 0.0, 1.0);

    return vec2(mapR - 0.5, mapG - 0.5) * GLITCH_DISPLACE_MAG;
}

vec4 effectGlitched(vec2 quadUV, float quadPhase, float pulseTime, float sphericalDist) {
    if (sphericalDist > GLITCH_MAX_DIST) return vec4(0.0);

    vec2 displacement = computeGlitchDisplacement(pulseTime, quadUV, quadPhase);
    vec2 sampleCentered = (quadUV + displacement) - 0.5;
    if (length(sampleCentered) * 2.0 > GLITCH_DISC_RADIUS) return vec4(0.0);

    float glitchAmount = clamp(length(displacement) * 3.0, 0.0, 1.0);
    return vec4(mix(GLITCH_BASE_COLOR, GLITCH_SHIFT_COLOR, glitchAmount), 1.0);
}


// ---------- Blue lightning ----------

vec4 effectBlueLightning(float d, float angle, float z, float pulseTime, float quadPhase) {
    float n = wavefrontNoise(d, angle, pulseTime + quadPhase);
    float threshold = wavefrontThreshold(d);
    float body = step(threshold, n) * z;
    float bodyBrightness = step(BLUE_GLOW_THRESHOLD, n - threshold);

    float filaments = computeFilaments(d, angle, pulseTime * 2.0 + quadPhase, quadPhase);

    float coreNoise = fbm(polarToNoiseSpace(d, angle, pulseTime + quadPhase, CORE_NOISE_SCALE, CORE_TIME_SCALE));
    float centerGlow = computeCoreLayer(d, coreNoise, CORE_GLOW_RADIUS, CORE_GLOW_THRESHOLD);
    float centerHot  = computeCoreLayer(d, coreNoise, CORE_HOT_RADIUS,  CORE_HOT_THRESHOLD);

    vec3 col = mix(BLUE_GRADIENT, vec3(1.0), bodyBrightness) * body;
    col = mix(col, FILAMENT_COLOR,  filaments);
    col = mix(col, CORE_GLOW_COLOR, centerGlow);
    col = mix(col, CORE_HOT_COLOR,  centerHot);

    float alpha = max(max(centerGlow, centerHot), max(filaments, body));
    return vec4(col, alpha);
}

#endif // THUNDERSTORM_PARTICLE_EFFECTS_GLSL