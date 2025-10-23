// LOVE2D compatible fragment shader for procedural nebula clouds using FBM
extern number time;
extern number scale;
extern vec3 tint;
extern number alpha;
extern vec2 offset;
extern vec2 center;
extern number cloudScale;
// New parameters to control procedural shape
extern number threshold; // how dense the cloud needs to be to be visible
extern number contrast;  // contrast/sharpness of the noise
extern number noiseScale; // extra multiplier on noise sampling

// 2D hash and noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian Motion
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(p);
        p = p * 2.0 + vec2(1.7, -2.0);
        amplitude *= 0.5;
    }
    return value;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Convert screen_coords to pixel-space UV and compute local UV relative to cloud center
    vec2 pixel = screen_coords.xy;
    vec2 local = pixel - center; // center provided in pixel coords
    // normalize local to [-1,1] range based on cloudScale
    vec2 uv = local / cloudScale;
    vec2 pos = uv * vec2(love_ScreenSize.x / love_ScreenSize.y, 1.0);
    pos *= scale * 1.0; // apply layer scale
    // stronger time motion for closer feeling and larger offset influence
    pos += vec2(time * 0.12, time * 0.06) + offset * 0.0025;


    // use multiple FBM layers at different frequencies to create richer shapes
    float baseNoise = fbm(pos * (0.6 * noiseScale));
    float mid  = fbm(pos * (1.2 * noiseScale) + vec2(12.3));
    float detail = fbm(pos * (2.6 * noiseScale) + vec2(42.7));
    // combine layers with weights to get interesting islands
    float clouds = baseNoise * 0.6 + mid * 0.3 + detail * 0.1;

    // apply contrast/threshold to carve irregular silhouettes instead of a circular blob
    // contrast pushes values away from 0.5 (higher = sharper)
    clouds = pow(clouds, 1.0 - contrast);
    // threshold determines what intensity counts as cloud; smoothstep for soft edges
    clouds = smoothstep(threshold - 0.12, threshold + 0.12, clouds);

    // color mixing with tint; reduce saturation slightly for distance
    // bring tint a bit closer to the original brighter blues/purples
    vec3 baseColor = vec3(0.85, 0.95, 1.0);
    vec3 col = tint * baseColor * clouds * 1.05;

    // final alpha with mask applied (boost a bit for closer feel)
    return vec4(col, clamp(clouds * alpha * 1.12, 0.0, 1.0));
}
