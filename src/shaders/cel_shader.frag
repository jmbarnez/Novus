extern vec2 ScreenSize;
extern float Time;
extern float PlasmaIntensity;
extern float GlowThreshold;
// New tunables added to improve tonemapping, saturation and bloom control
extern float Exposure;
extern float Saturation;
extern float BloomAmount;
extern float UseChromatic; // 0.0 = off, 1.0 = on

// Pseudo-random function for noise
float rand(vec2 c) {
    return fract(sin(dot(c.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Perlin-like noise function (value noise)
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Interpolation curve
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float n00 = rand(i + vec2(0.0, 0.0));
    float n10 = rand(i + vec2(1.0, 0.0));
    float n01 = rand(i + vec2(0.0, 1.0));
    float n11 = rand(i + vec2(1.0, 1.0));
    
    float nx0 = mix(n00, n10, u.x);
    float nx1 = mix(n01, n11, u.x);
    return mix(nx0, nx1, u.y);
}

// Fractional Brownian motion for natural-looking clouds
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        maxValue += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value / maxValue;
}

// Simple ACES-like exposure tonemapping (cheap approx)
vec3 tonemap(vec3 c, float exposure) {
    c = vec3(1.0) - exp(-c * exposure);
    // Soft clamp
    return clamp(c, 0.0, 1.0);
}

// Adjust saturation around luminance
vec3 adjustSaturation(vec3 col, float sat) {
    float gray = dot(col, vec3(0.299, 0.587, 0.114));
    return mix(vec3(gray), col, sat);
}

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, tex_coords);
    
    // Pass through transparent pixels
    if (texcolor.a < 0.01) {
        return texcolor;
    }
    
    vec3 rgb = texcolor.rgb;
    float brightness = dot(rgb, vec3(0.299, 0.587, 0.114));
    
    // ==== PLASMA EFFECT ====
    
    // 1. ENERGIZE BRIGHT COLORS - Make glowing things REALLY glow
    if (brightness > GlowThreshold) {
        // Exponential brightness boost for engines, lasers, bright objects
        float energyBoost = (brightness - GlowThreshold) / (1.0 - GlowThreshold);
        energyBoost = pow(energyBoost, 0.6) * PlasmaIntensity;
        rgb = rgb * (1.0 + energyBoost * 1.8);
    }
    
    // 2. PLASMA FIELD WAVES - Wave distortion throughout space
    // Subtle world-space wave distortion (cheap, reduced amplitude)
    float waveX = sin(screen_coords.x * 0.0025 + Time * 1.2) * 0.05;
    float waveY = cos(screen_coords.y * 0.0025 + Time * 1.0) * 0.05;
    float waveMix = (waveX + waveY) * brightness * 0.45;
    
    // Sample shifted coordinates for displacement
    vec2 distortCoords = tex_coords + vec2(waveX * 0.001, waveY * 0.001);
    vec4 distortedColor = Texel(texture, distortCoords);
    
    // Blend original with distorted based on plasma intensity
    rgb = mix(rgb, distortedColor.rgb, clamp(waveMix * PlasmaIntensity * 0.28, 0.0, 1.0));
    
    // 3. GLOW/BLOOM - Colors expand outward
    // Compact bloom: fewer samples, tunable bloom strength
    if (brightness > 0.35) {
        vec2 pixelSize = 1.0 / ScreenSize;
        // four diagonal samples (cheaper and less banding)
        vec3 b1 = Texel(texture, tex_coords + vec2(pixelSize.x * 1.5, pixelSize.y * 1.5)).rgb;
        vec3 b2 = Texel(texture, tex_coords + vec2(-pixelSize.x * 1.5, pixelSize.y * 1.5)).rgb;
        vec3 b3 = Texel(texture, tex_coords + vec2(pixelSize.x * 1.5, -pixelSize.y * 1.5)).rgb;
        vec3 b4 = Texel(texture, tex_coords + vec2(-pixelSize.x * 1.5, -pixelSize.y * 1.5)).rgb;
        vec3 bloomColor = (b1 + b2 + b3 + b4) * 0.25;

        float bloomFactor = clamp((brightness - 0.35) * 1.6 * PlasmaIntensity * (BloomAmount > 0.0 ? BloomAmount : 1.0), 0.0, 1.0);
        rgb = mix(rgb, bloomColor, bloomFactor * 0.25);
    }
    
    // 4. ENERGY FIELD PULSE - Pulsing glow effect
    float pulse = sin(Time * 2.5) * 0.5 + 0.5;
    if (brightness > 0.5) {
        rgb = rgb * (1.0 + pulse * 0.18 * PlasmaIntensity);
    }
    
    // 5. CHROMATIC ABERRATION - Color bleeding for bright areas
    // Chromatic aberration only if enabled to save cost
    if (brightness > 0.6 && UseChromatic > 0.5) {
        vec2 pixelSize = 1.0 / ScreenSize;
        float aberration = clamp(1.5 * PlasmaIntensity, 0.2, 4.0) * (BloomAmount > 0.0 ? BloomAmount : 1.0);
        float redShift = Texel(texture, tex_coords + vec2(pixelSize.x * aberration, 0)).r;
        float blueShift = Texel(texture, tex_coords - vec2(pixelSize.x * aberration, 0)).b;
        rgb.r = mix(rgb.r, redShift, 0.22);
        rgb.b = mix(rgb.b, blueShift, 0.22);
    }
    
    // 6. SPACE VIGNETTE - Fade to dark space at edges (optional subtle effect)
    // Only apply to bright objects, not stars
    if (brightness > 0.5) {
        float distFromCenter = length((screen_coords - ScreenSize * 0.5) / ScreenSize);
        float vignette = smoothstep(1.0, 0.0, distFromCenter);
        rgb = mix(rgb, rgb * 0.82, (1.0 - vignette) * 0.09);
    }
    
    // 7. OVERALL ENERGY SATURATION - Make colors more vivid (only for bright objects)
    if (brightness > 0.5) {
        float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
        // slightly boost saturation for energetic highlights
        rgb = mix(vec3(gray), rgb, clamp(1.0 + 0.2 * PlasmaIntensity, 0.0, 1.6));
    }

    // Global tonemap and exposure/saturation control
    rgb = tonemap(rgb * (Exposure > 0.0 ? Exposure : 1.0), (Exposure > 0.0 ? Exposure : 1.0));
    rgb = adjustSaturation(rgb, (Saturation > 0.0 ? Saturation : 1.0));

    return vec4(clamp(rgb, 0.0, 1.0), texcolor.a) * color;
}

