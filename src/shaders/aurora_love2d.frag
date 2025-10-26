// Aurora Borealis Shader - Love2D format
extern float time;
extern vec2 resolution;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;
extern vec4 textBounds;

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    // Simple aurora effect
    vec2 p = screen_coords / resolution;
    
    // Create flowing wave patterns
    float wave1 = sin(p.x * 4.0 + time * 1.2) * 0.5 + 0.5;
    float wave2 = sin(p.x * 3.0 - time * 0.8 + 1.5) * 0.5 + 0.5;
    float wavePattern = (wave1 + wave2) * 0.5;
    
    // Simple color cycling
    vec3 auroraColor = mix(color1, color2, wavePattern);
    
    // Simple alpha
    float alpha = 0.7;
    
    return vec4(auroraColor, alpha);
}
