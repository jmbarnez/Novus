// Minimal Test Shader
uniform float time;

varying vec2 texCoord;
varying vec2 screenPos;

void main() {
    // Just return a simple color that changes over time
    vec3 color = vec3(
        0.5 + 0.5 * sin(time),
        0.5 + 0.5 * sin(time + 2.0),
        0.5 + 0.5 * sin(time + 4.0)
    );
    
    gl_FragColor = vec4(color, 0.8);
}
