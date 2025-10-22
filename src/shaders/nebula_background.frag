extern float Time;
extern float NebulaIntensity;
extern vec2 CameraOffset;

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
    // Generate nebula clouds procedurally
    vec2 worldCoord = screen_coords + CameraOffset;
    
    // Smaller scale for huge, distant clouds
    vec2 cloudCoord = worldCoord * 0.00008;
    
    // Layer 1: Slow-moving base nebula
    float nebula1 = fbm(cloudCoord + Time * 0.01);
    
    // Layer 2: Medium-speed nebula (different phase)
    float nebula2 = fbm(cloudCoord * 0.6 + Time * 0.02 + vec2(2000.0, 1000.0));
    
    // Layer 3: Very subtle fine details
    float nebula3 = fbm(cloudCoord * 0.9 + Time * 0.04 + vec2(1000.0, 2000.0));
    
    // Combine layers with emphasis on base structure
    float nebulaMask = nebula1 * 0.7 + nebula2 * 0.2 + nebula3 * 0.1;
    
    // Smoother threshold for large, flowing clouds
    nebulaMask = smoothstep(0.3, 0.7, nebulaMask);
    
    // Create nebula colors - subtle distant tones
    vec3 nebulaCool = vec3(0.1, 0.2, 0.4);     // Cool blue
    vec3 nebulaWarm = vec3(0.4, 0.15, 0.1);    // Warm orange
    vec3 nebulaPurp = vec3(0.35, 0.1, 0.45);   // Purple
    
    // Color varies smoothly based on world position
    float colorShift = sin(cloudCoord.x * 0.3 + Time * 0.005) * 0.5 + 0.5;
    vec3 nebulaColor = mix(nebulaCool, nebulaWarm, colorShift);
    
    // Add purple tones smoothly in some regions
    float purpleShift = sin(cloudCoord.y * 0.2 + Time * 0.01) * 0.5 + 0.5;
    nebulaColor = mix(nebulaColor, nebulaPurp, purpleShift * 0.25);
    
    // Huge distant clouds with good visibility
    float nebulaAlpha = nebulaMask * NebulaIntensity;
    
    // Return nebula with good opacity
    return vec4(nebulaColor, nebulaAlpha * 0.3);
}
