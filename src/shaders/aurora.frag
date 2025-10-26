// Aurora Borealis Fragment Shader
uniform float time;
uniform vec2 resolution;
uniform vec3 color1;
uniform vec3 color2;
uniform vec3 color3;
uniform vec4 textBounds; // x, y, width, height of text

varying vec2 texCoord;
varying vec2 screenPos;

// Simple noise function
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Fractal Brownian motion for more complex noise
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void main() {
    // Check if we're within the bounds
    vec2 boundsCenter = vec2(textBounds.x + textBounds.z * 0.5, textBounds.y + textBounds.w * 0.5);
    vec2 toCenter = screenPos - boundsCenter;
    float distanceFromCenter = length(toCenter);

    // Create a falloff based on distance from bounds center (for background effect)
    float maxDistance = length(vec2(textBounds.z * 0.6, textBounds.w * 0.6));
    float boundsInfluence = 1.0 - smoothstep(0.0, maxDistance, distanceFromCenter);

    // Only apply aurora effect if we're within the bounds
    if (boundsInfluence < 0.01) {
        discard; // Don't draw pixels outside bounds
    }

    // Use screen position for wave calculations
    vec2 p = (screenPos - boundsCenter) / (textBounds.w * 0.5);
    p.x *= resolution.x / resolution.y;

    // Create flowing wave patterns with higher frequency for more detail
    float wave1 = sin(p.x * 4.0 + time * 1.2) * 0.5 + 0.5;
    float wave2 = sin(p.x * 3.0 - time * 0.8 + 1.5) * 0.5 + 0.5;
    float wave3 = sin(p.x * 5.0 + time * 1.8 - 0.7) * 0.5 + 0.5;
    float wave4 = sin(p.x * 2.5 + p.y * 2.0 + time * 0.6) * 0.3 + 0.7;

    // Combine waves for complex motion
    float wavePattern = (wave1 * 0.3 + wave2 * 0.3 + wave3 * 0.2 + wave4 * 0.2);

    // Add vertical flow with more variation
    float verticalFlow = sin(p.y * 3.0 + time * 0.9) * 0.4 + 0.6;
    verticalFlow += sin(p.y * 1.5 - time * 1.3) * 0.2;

    // Create intensity variation with higher base values
    float intensity = wavePattern * verticalFlow * boundsInfluence * 1.2;

    // Add some noise for realism
    float noiseValue = fbm(p * 2.0 + time * 0.5) * 0.3 + 0.7;
    intensity *= noiseValue;

    // Simple time-based color cycling
    vec3 auroraColor;

    // Create a 0-1 cycling value based on time
    float cycle = (sin(time * 0.5 + p.x * 0.3) + 1.0) * 0.5;

    // Create smooth transitions between the three colors
    float phase = cycle * 3.0; // Scale to 0-3 range for 3 transitions

    if (phase < 1.0) {
        auroraColor = mix(color1, color2, smoothstep(0.0, 1.0, phase));
    } else if (phase < 2.0) {
        auroraColor = mix(color2, color3, smoothstep(1.0, 2.0, phase));
    } else {
        auroraColor = mix(color3, color1 * 1.2, smoothstep(2.0, 3.0, phase));
    }

    // Add some variation based on vertical position
    float verticalVariation = (sin(time * 0.3 + p.y * 2.0) + 1.0) * 0.1;
    auroraColor.r += verticalVariation;
    auroraColor.g -= verticalVariation * 0.5;
    auroraColor.b += verticalVariation * 0.3;

    // Clamp colors to valid range
    auroraColor = clamp(auroraColor, 0.0, 1.0);

    // Add some brightness variation
    float brightness = 0.6 + 0.4 * sin(time * 2.0 + p.x * 2.0);
    auroraColor *= brightness;

    // Create alpha based on intensity with smooth falloff
    float alpha = smoothstep(0.05, 0.8, intensity); // Wider visible range
    alpha *= smoothstep(0.05, 0.8, noiseValue); // Use noise for natural edges
    alpha *= boundsInfluence; // Fade out away from bounds

    // Add some transparency variation over time
    alpha *= 0.95 + 0.05 * sin(time * 1.5 + p.x * 3.0);

    // Ensure minimum visibility but allow natural fading
    alpha = max(alpha, 0.25);

    gl_FragColor = vec4(auroraColor, alpha);
}
