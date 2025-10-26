// Aurora Borealis Fragment Shader - Simplified
uniform float time;
uniform vec2 resolution;
uniform vec3 color1;
uniform vec3 color2;
uniform vec3 color3;
uniform vec4 textBounds;

varying vec2 texCoord;
varying vec2 screenPos;

void main() {
    // Simple aurora effect
    vec2 p = screenPos / resolution;
    
    // Create flowing wave patterns
    float wave1 = sin(p.x * 4.0 + time * 1.2) * 0.5 + 0.5;
    float wave2 = sin(p.x * 3.0 - time * 0.8 + 1.5) * 0.5 + 0.5;
    float wavePattern = (wave1 + wave2) * 0.5;
    
    // Simple color cycling
    vec3 auroraColor = mix(color1, color2, wavePattern);
    
    // Simple alpha
    float alpha = 0.7;
    
    gl_FragColor = vec4(auroraColor, alpha);
}
