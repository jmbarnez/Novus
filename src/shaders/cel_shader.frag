extern vec2 ScreenSize;
extern float Time;
extern float PlasmaIntensity;
extern float GlowThreshold;

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
        rgb = rgb * (1.0 + energyBoost * 2.0);
    }
    
    // 2. PLASMA FIELD WAVES - Wave distortion throughout space
    float waveX = sin(screen_coords.x * 0.003 + Time * 1.5) * 0.08;
    float waveY = cos(screen_coords.y * 0.003 + Time * 1.2) * 0.08;
    float waveMix = (waveX + waveY) * brightness * 0.5;
    
    // Sample shifted coordinates for displacement
    vec2 distortCoords = tex_coords + vec2(waveX * 0.001, waveY * 0.001);
    vec4 distortedColor = Texel(texture, distortCoords);
    
    // Blend original with distorted based on plasma intensity
    rgb = mix(rgb, distortedColor.rgb, waveMix * PlasmaIntensity * 0.3);
    
    // 3. GLOW/BLOOM - Colors expand outward
    if (brightness > 0.4) {
        vec2 pixelSize = 1.0 / ScreenSize;
        
        // Sample neighbors for bloom effect
        vec4 sampleN = Texel(texture, tex_coords + vec2(0, pixelSize.y * 2.0));
        vec4 sampleS = Texel(texture, tex_coords - vec2(0, pixelSize.y * 2.0));
        vec4 sampleE = Texel(texture, tex_coords + vec2(pixelSize.x * 2.0, 0));
        vec4 sampleW = Texel(texture, tex_coords - vec2(pixelSize.x * 2.0, 0));
        
        // Average neighboring pixels
        vec3 bloomColor = (sampleN.rgb + sampleS.rgb + sampleE.rgb + sampleW.rgb) * 0.25;
        
        // Bloom amount based on brightness
        float bloomAmount = (brightness - 0.4) * 1.5 * PlasmaIntensity;
        rgb = mix(rgb, bloomColor, bloomAmount * 0.2);
    }
    
    // 4. ENERGY FIELD PULSE - Pulsing glow effect
    float pulse = sin(Time * 3.0) * 0.5 + 0.5;
    if (brightness > 0.5) {
        rgb = rgb * (1.0 + pulse * 0.2 * PlasmaIntensity);
    }
    
    // 5. CHROMATIC ABERRATION - Color bleeding for bright areas
    if (brightness > 0.6) {
        vec2 pixelSize = 1.0 / ScreenSize;
        float aberration = 2.0 * PlasmaIntensity;
        
        float redShift = Texel(texture, tex_coords + vec2(pixelSize.x * aberration, 0)).r;
        float blueShift = Texel(texture, tex_coords - vec2(pixelSize.x * aberration, 0)).b;
        
        rgb.r = mix(rgb.r, redShift, 0.3);
        rgb.b = mix(rgb.b, blueShift, 0.3);
    }
    
    // 6. SPACE VIGNETTE - Fade to dark space at edges (optional subtle effect)
    // Only apply to bright objects, not stars
    if (brightness > 0.5) {
        float distFromCenter = length((screen_coords - ScreenSize * 0.5) / ScreenSize);
        float vignette = smoothstep(1.0, 0.0, distFromCenter);
        rgb = mix(rgb, rgb * 0.8, (1.0 - vignette) * 0.1);
    }
    
    // 7. OVERALL ENERGY SATURATION - Make colors more vivid (only for bright objects)
    if (brightness > 0.5) {
        float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
        rgb = mix(vec3(gray), rgb, 1.2);
    }
    
    return vec4(rgb, texcolor.a) * color;
}

