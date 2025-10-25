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
    // Check if we're within the text bounds
    vec2 textCenter = vec2(textBounds.x + textBounds.z * 0.5, textBounds.y + textBounds.w * 0.5);
    vec2 toCenter = screenPos - textCenter;
    float distanceFromCenter = length(toCenter);

    // Create a falloff based on distance from text center
    float textInfluence = 1.0 - smoothstep(0.0, textBounds.w * 0.8, distanceFromCenter);

    // Only apply aurora effect if we're near the text
    if (textInfluence < 0.01) {
        discard; // Don't draw pixels far from text
    }

    // Use screen position for wave calculations
    vec2 p = (screenPos - textCenter) / (textBounds.w * 0.5);
    p.x *= resolution.x / resolution.y;

    // Create flowing wave patterns
    float wave1 = sin(p.x * 2.0 + time * 1.2) * 0.5 + 0.5;
    float wave2 = sin(p.x * 1.5 - time * 0.8 + 1.5) * 0.5 + 0.5;
    float wave3 = sin(p.x * 3.0 + time * 1.8 - 0.7) * 0.5 + 0.5;

    // Combine waves for complex motion
    float wavePattern = (wave1 * 0.4 + wave2 * 0.3 + wave3 * 0.3);

    // Add vertical flow
    float verticalFlow = sin(p.y * 1.5 + time * 0.9) * 0.3 + 0.7;

    // Create intensity variation
    float intensity = wavePattern * verticalFlow * textInfluence;

    // Add some noise for realism
    float noiseValue = fbm(p * 2.0 + time * 0.5) * 0.3 + 0.7;
    intensity *= noiseValue;

    // Create smooth color transitions
    vec3 auroraColor;
    float colorMix1 = smoothstep(0.0, 0.4, intensity);
    float colorMix2 = smoothstep(0.4, 0.8, intensity);
    float colorMix3 = smoothstep(0.8, 1.0, intensity);

    // Blend between aurora colors
    auroraColor = mix(color1, color2, colorMix1);
    auroraColor = mix(auroraColor, color3, colorMix2);
    auroraColor = mix(auroraColor, color1 * 1.2, colorMix3);

    // Add some brightness variation
    float brightness = 0.6 + 0.4 * sin(time * 2.0 + p.x * 2.0);
    auroraColor *= brightness;

    // Create alpha based on intensity with smooth falloff
    float alpha = intensity * intensity * (3.0 - 2.0 * intensity); // Smoothstep
    alpha *= smoothstep(0.1, 0.9, noiseValue); // Use noise for natural edges
    alpha *= textInfluence; // Fade out away from text

    // Add some transparency variation over time
    alpha *= 0.8 + 0.2 * sin(time * 1.5 + p.x * 3.0);

    // Ensure alpha doesn't go completely transparent
    alpha = max(alpha, 0.05);

    gl_FragColor = vec4(auroraColor, alpha);
}
