// Energy Laser Shader - Plasma-themed laser beams with glow and pulse
extern float Time;
extern vec3 LaserColor;      // Base color of laser (RGB)
extern float Intensity;      // Overall brightness multiplier
extern float PulseSpeed;     // Speed of energy pulse

// Simple noise for energy turbulence
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    // Distance from center of laser (y-axis is perpendicular to beam)
    // tex_coords.y goes from 0 to 1 across the width of the beam
    float distFromCenter = abs(tex_coords.y - 0.5) * 2.0; // 0 at center, 1 at edges
    
    // Core brightness - brightest at center, fades to edges
    float coreBrightness = 1.0 - smoothstep(0.0, 0.6, distFromCenter);
    
    // Energy pulse traveling along laser
    float pulse = sin(tex_coords.x * 10.0 - Time * PulseSpeed) * 0.5 + 0.5;
    pulse = pow(pulse, 2.0); // Sharpen the pulse
    
    // Energy turbulence - subtle noise flowing along beam
    vec2 noiseCoord = vec2(tex_coords.x * 5.0 - Time * 2.0, tex_coords.y * 20.0);
    float turbulence = noise(noiseCoord) * 0.3;
    
    // Outer glow - extends to edges
    float glowBrightness = 1.0 - smoothstep(0.3, 1.0, distFromCenter);
    
    // Combine effects
    float finalBrightness = coreBrightness * (1.0 + pulse * 0.5 + turbulence);
    finalBrightness += glowBrightness * 0.4; // Add soft glow
    finalBrightness *= Intensity;
    
    // Color shifts slightly with pulse (towards white when pulsing)
    vec3 finalColor = mix(LaserColor, vec3(1.0, 1.0, 1.0), pulse * 0.3);
    finalColor *= finalBrightness;
    
    // Output with smooth alpha falloff from center to edges
    float alpha = 1.0 - smoothstep(0.2, 1.0, distFromCenter);
    return vec4(finalColor, alpha) * color;
}
