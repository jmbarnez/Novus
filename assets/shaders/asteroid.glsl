// Satisfying asteroid shader with smooth, organic rocky surfaces
// Designed for visually pleasing 2D space aesthetics

extern number seed;

#ifdef PIXEL
// 2D hash
float hash(vec2 p)
{
    // Large, semi-random constants help decorrelate coordinates
    p = vec2(
        dot(p, vec2(127.1, 311.7)),
        dot(p, vec2(269.5, 183.3))
    );
    return fract(sin(p.x + p.y) * 43758.5453123);
}

// Smooth value noise
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    // Quintic interpolation for smoother derivatives
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for organic patterns
float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;
    float gain = 0.5;
    float lacunarity = 2.3;

    // 4 octaves is a good balance of detail vs cost
    for (int i = 0; i < 4; i++)
    {
        value += amplitude * noise(p);
        p *= lacunarity;
        amplitude *= gain;
    }

    return value;
}

// Ridged noise for crater-like / sharp features
float ridged(vec2 p)
{
    float n = noise(p);
    n = 2.0 * n - 1.0;      // [-1, 1]
    n = 1.0 - abs(n);       // ridges
    return n * n;           // emphasize ridges
}

// Simple radial mask to soften edges and suggest a round-ish body
float radialMask(vec2 uv)
{
    vec2 centered = uv - 0.5;
    float r = length(centered) * 2.0; // 0 at center, ~1 at edge
    // Inner fully opaque, outer faded
    return 1.0 - smoothstep(0.8, 1.0, r);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;

    // Use uv as local asteroid UV (0–1). Seed offsets to vary asteroids.
    vec2 pos = (uv + seed * 7.531) * 3.0;

    // Organic rocky base structure
    float base = fbm(pos);

    // Add subtle crater-like features
    float craters = ridged(pos * 1.5 + base * 0.3) * 0.35;

    // Fine surface detail
    float detail = noise(pos * 8.0 + seed * 13.17) * 0.18;

    // Large-scale albedo variation to break uniformity
    float macro = fbm(pos * 0.4 + seed * 2.71) * 0.35;

    // Combine layers for depth
    float combined = base * 0.55 + craters + detail + macro;

    // Slight curvature shading (fake light from top-right)
    vec2 lightDir = normalize(vec2(0.6, -0.8));
    vec2 centerVec = normalize((uv - 0.5) * 2.0);
    float curvature = dot(-centerVec, lightDir) * 0.5 + 0.5;
    curvature = mix(0.8, 1.2, curvature);
    combined *= curvature;

    // Clamp combined height-like value
    combined = clamp(combined, 0.0, 1.0);

    // Color variation with smooth gradients
    vec3 darkTone  = color.rgb * vec3(0.45, 0.48, 0.5);
    vec3 midTone   = color.rgb * vec3(0.8, 0.82, 0.85);
    vec3 lightTone = color.rgb * vec3(1.25, 1.2, 1.15);

    // Tri-band gradient for more interesting rock coloration
    vec3 rocky = mix(darkTone, midTone, smoothstep(0.1, 0.6, combined));
    rocky = mix(rocky, lightTone, smoothstep(0.5, 0.95, combined));

    // Subtle color tint variation based on position to avoid flat hue
    float tintNoise = fbm(pos * 0.7 + 12.37);
    vec3 tint = mix(vec3(0.95, 0.98, 1.0), vec3(1.02, 0.98, 0.95), tintNoise);
    vec3 finalColor = rocky * tint;

    // Subtle edge darkening for depth
    float edge = smoothstep(0.0, 0.35, length(uv - 0.5) * 2.0);
    finalColor = mix(finalColor, finalColor * 0.78, edge * 0.35);

    // Soft contrast for a polished look (slight gamma tweak)
    finalColor = pow(finalColor, vec3(0.95));

    // Radial alpha mask to softly fade asteroid into background
    float alphaMask = radialMask(uv);

    return vec4(finalColor, color.a * alphaMask);
}
#endif
