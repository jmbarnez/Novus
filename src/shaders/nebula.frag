extern float time;
extern vec2 resolution;
extern vec3 nebulaColor1;
extern vec3 nebulaColor2;
extern vec3 nebulaColor3;
extern float nebulaIntensity;
extern float nebulaDim;

// Hash / value noise helpers
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.0;
        a *= 0.5;
    }
    return v;
}

vec3 vibrant(vec3 base, float t) {
    return pow(base, vec3(0.9)) * (0.8 + 0.4 * t);
}

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    vec2 p = screen_coords / resolution;
    // Aspect-correct and center for full-screen coverage
    p = (p - 0.5) * vec2(resolution.x / resolution.y, 1.0) + 0.5;

    vec3 rgb = vec3(0.0);
    float maxMask = 0.0;

    // Scale up world coordinates to make clouds appear more distant and cover the screen
    vec2 worldP = (screen_coords / resolution - 0.5) * 2.0;
    worldP *= vec2(resolution.x / resolution.y, 1.0);
    worldP *= 1.2; // smaller world scale so clouds appear bigger

    // Slow down time for a distant, drifting effect
    float slowTime = time * 0.02;

    // Create 3 large vibrant cloud blobs with procedural placement and mixed colors
    for (int i = 0; i < 3; i++) {
        float fi = float(i) + 1.0;

        // Procedural hash values for this blob (stable per index)
        float h1 = hash(vec2(fi, 12.9898 + fi));
        float h2 = hash(vec2(fi * 2.31, 78.233 + fi));
        float h3 = hash(vec2(fi * 3.7, 127.1 + fi));

        // Base center in world space, then add organic jitter using FBM
        vec2 baseCenter = (vec2(h1, h2) - 0.5) * vec2(1.6, 1.1);
        vec2 jitter = vec2(fbm(baseCenter * 2.0 + vec2(h3 * 7.0)), fbm(baseCenter * 2.3 - vec2(h1 * 5.0)));
        vec2 center = baseCenter + (jitter - 0.5) * 0.6;

        // Very slow drifting motion for distant feel
        center += vec2(sin(slowTime * (0.08 + h2 * 0.03) + fi * 0.7) * 0.06,
                       cos(slowTime * (0.06 + h1 * 0.02) - fi * 0.9) * 0.05);

        // Procedural radius variation (slightly smaller clouds)
        float radius = 0.35 + 0.4 * h3 + 0.12 * float(i);
        radius = clamp(radius, 0.35, 1.0);

        // Distance in world space
        float d = length(worldP - center);

        // Smooth circular mask
        float mask = 1.0 - smoothstep(radius * 0.5, radius, d);
        if (mask <= 0.001) continue;

        // Textured detail inside the blob using FBM (larger scale so details are distant)
        float detailScale = 2.0 + 6.0 * (1.0 - h3);
        float detail = fbm((worldP - center) * detailScale + vec2(slowTime * (0.6 + h2 * 0.3), -slowTime * (0.4 + h1 * 0.2)));
        detail = smoothstep(0.12, 0.9, detail);

        // Mixed base color computed procedurally per-blob using FBM weights
        float wA = smoothstep(0.0, 1.0, fbm(center * 1.3 + vec2(h1 * 2.0, h2 * 1.0) + slowTime * 0.15));
        float wB = smoothstep(0.0, 1.0, fbm(center * 1.7 + vec2(h2 * 2.2, h3 * 0.5) - slowTime * 0.12));
        vec3 mix12 = mix(nebulaColor1, nebulaColor2, wA);
        vec3 mix23 = mix(nebulaColor2, nebulaColor3, wB);
        float mixWeight = clamp(wA * 0.6 + wB * 0.4, 0.0, 1.0);
        vec3 baseColor = mix(mix12, mix23, mixWeight);

        // Per-pixel tint variation so cloud interiors shift colors subtly
        float tintVar = fbm((worldP - center) * 0.8 + vec2(h3 * 3.0, -h2 * 2.0) + slowTime * 0.08);
        vec3 col = vibrant(mix(baseColor, vec3(0.95, 0.95, 1.0), 0.06 * (tintVar - 0.5)), tintVar);

        // Wispiness modifier so edges are softer
        float wisp = pow(detail, 1.1 + 0.4 * (1.0 - h3)) * mask;

        // Strength variation per blob
        float strength = 0.7 + 0.6 * h1;
        rgb += col * wisp * strength;
        maxMask = max(maxMask, mask * detail);
    }

    // Final color adjustments
    // Slight tone mapping and soften
    rgb = pow(rgb, vec3(0.98));
    float alpha = clamp(maxMask * nebulaIntensity * 1.2, 0.0, 1.0);
    alpha *= smoothstep(0.0, 1.0, maxMask);
    alpha *= (nebulaDim > 0.0 ? nebulaDim : 1.0);

    vec3 finalRgb = rgb * (0.5 + 0.5 * (nebulaDim > 0.0 ? nebulaDim : 1.0));
    return vec4(finalRgb, alpha) * color;
}
