extern float time;
extern vec2 resolution;
extern vec2 cameraOffset;

// Hash function for noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Smooth noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i + vec2(0.0, 0.0));
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractional Brownian Motion for swirling patterns
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 6; i++) {
        v += a * noise(p * frequency);
        frequency *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    // Convert to normalized coordinates
    vec2 uv = screen_coords / resolution;
    
    // Center and aspect-correct
    uv = (uv - 0.5) * vec2(resolution.x / resolution.y, 1.0);
    
    // Add camera parallax (very deep background layer - moves very slowly)
    vec2 worldPos = uv + cameraOffset * 0.0001;
    
    // Create swirling effect using polar coordinates
    float angle = atan(worldPos.y, worldPos.x);
    float radius = length(worldPos);
    
    // Swirl distortion - combine rotation with radius (much slower animation)
    float swirl = angle + radius * 0.8 + time * 0.02;
    vec2 swirlPos = vec2(
        cos(swirl) * radius,
        sin(swirl) * radius
    );
    
    // Scale for pattern size
    float scale = 0.3;
    vec2 noisePos = swirlPos * scale + vec2(time * 0.003, time * 0.005);  // Very slow drift
    
    // Generate noise patterns for the swirl
    float n1 = fbm(noisePos);
    float n2 = fbm(noisePos * 1.8 + vec2(100.0, 50.0));
    float n3 = fbm(noisePos * 3.2 + vec2(200.0, 150.0));
    
    // Combine noise layers for rich detail
    float density = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    density = smoothstep(0.2, 0.8, density);
    
    // Create blue-cyan gradient, minimizing green
    vec3 blueColor = vec3(0.1, 0.3, 0.65);   // Rich blue
    vec3 cyanColor = vec3(0.1, 0.65, 0.8);    // Vibrant cyan (less green)
    vec3 tealColor = vec3(0.1, 0.5, 0.6);   // Teal (blue-cyan, minimal green)
    
    // Mix colors based on swirl position and noise, favoring blue and cyan
    float colorMix = (swirlPos.y * 0.3 + n1 * 0.5 + 0.5);
    colorMix = smoothstep(0.0, 1.0, colorMix);
    
    // Three-way mix: blue->cyan->teal (avoid pure green)
    vec3 baseColor;
    if (colorMix < 0.6) {
        // Mix blue to cyan (most of the range)
        baseColor = mix(blueColor, cyanColor, colorMix / 0.6);
    } else {
        // Mix cyan to teal (minimal green in teal)
        baseColor = mix(cyanColor, tealColor, (colorMix - 0.6) / 0.4);
    }
    
    // Add blue-cyan tinted variation, reduce green component
    float variation = n2 * 0.3;
    vec3 finalColor = baseColor + variation * vec3(0.1, 0.15, 0.2);  // More blue/cyan, less green
    
    // Apply density for smooth fade
    finalColor *= (0.3 + density * 0.7);
    
    // Ensure minimum brightness so it's not too dark (blue-cyan tinted minimum)
    finalColor = max(finalColor, vec3(0.12, 0.18, 0.25));
    
    // Clamp to reasonable values (limit green channel to reduce green appearance)
    finalColor = clamp(finalColor, vec3(0.1, 0.15, 0.2), vec3(0.5, 0.65, 0.8));
    
    return vec4(finalColor, 1.0) * color;
}

