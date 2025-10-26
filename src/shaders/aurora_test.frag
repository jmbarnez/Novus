// Simple Aurora Test Fragment Shader
uniform float time;
uniform vec2 resolution;
uniform vec3 color1;
uniform vec3 color2;
uniform vec3 color3;
uniform vec4 textBounds;

varying vec2 texCoord;
varying vec2 screenPos;

void main() {
    // Simple test: just return a cycling color
    vec3 testColor = vec3(
        0.5 + 0.5 * sin(time + screenPos.x * 0.01),
        0.5 + 0.5 * sin(time * 1.1 + screenPos.y * 0.01),
        0.8 + 0.2 * sin(time * 0.7)
    );
    
    gl_FragColor = vec4(testColor, 0.8);
}
